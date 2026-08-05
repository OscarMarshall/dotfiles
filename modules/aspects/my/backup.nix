let
  # The account-level B2 key ID (paired with the b2-application-key secret below) that
  # authenticates the `b2` Terraform provider - shared across every host that includes this
  # aspect, since there's only one Backblaze account, not one per host. Unlike `applicationKeyId`
  # (still a my.backup parameter below - it genuinely varies per host, one bucket-scoped key
  # each), duplicating THIS at every host's own call site would just be the same literal typed N
  # times, and a key rotation would mean hunting down N call sites instead of one - so it lives
  # here once instead.
  #
  # A plain Nix value, not a secret, despite sitting right next to ones that are - Backblaze
  # documents applicationKeyId as visible/findable in the console at any time (like a username),
  # unlike applicationKey itself (shown once, at creation, like a password). Same "identifier,
  # not a credential" distinction dns.nix draws for `host.cloudflare-zone-id`.
  accountApplicationKeyId = "004119677af80560000000001";
in
{
  # `bucket` is the single source of truth for both restic's repository (below) and the
  # Terraform-managed b2_bucket resource (in `terranix`, below) - so there's exactly one place to
  # rename it, rather than a Nix-side string and a Terraform-side string drifting apart.
  #
  # `applicationKeyId` is a plain Nix value, not a secret, despite sitting right next to ones
  # that are - same reasoning as `accountApplicationKeyId` above, but this one genuinely does
  # vary per host (each host's own bucket-scoped key), so it stays a parameter. `null` by default
  # for the same reason: the bucket (via `terranix`, below) has to exist before this key can even
  # be created (see the bootstrap TODO in harmony.nix), but there's no reason to wait on that
  # before wiring this aspect in. While it's null, `nixos` below defines no restic jobs at all,
  # rather than jobs that are guaranteed to fail authentication the moment a rebuild actually
  # applies them.
  my.backup =
    {
      bucket,
      applicationKeyId ? null,
    }:
    { host, ... }:
    let
      # The bucket-scoped restic key is genuinely different per host (each host gets its own
      # bucket - see the per-host-bucket discussion this aspect was built from), so its secret
      # name - and therefore its `rekeyFile` - has to be too. Without `-${host.name}`, a second
      # host including this aspect would rekey the exact same `secrets/backup-b2-*.age` file
      # harmony uses, silently handing it a key that has no access to ITS bucket. Same fix
      # terranix.nix already applies to `"${host.name}-tf.env"`, for the same reason.
      #
      # `b2-application-key` (below, no per-host suffix) deliberately does NOT get this treatment
      # - it authenticates Terraform against the ONE Backblaze account every host shares, so
      # reusing the same key/secret across hosts is correct, not a bug.
      backupKeySecretName = "backup-b2-application-key-${host.name}";
    in
    {
      nixos =
        {
          config,
          lib,
          pkgs,
          dataset,
          ...
        }:
        let
          # `backup` is either `true` (defaults below, untouched) or a `pkgs: {...}` function
          # returning restic job option overrides - the same deferred-value pattern
          # minecraft-servers.nix uses for `worlds.<name>.server`, needed here because `dataset`
          # is plain data assembled before `pkgs` exists at an owning aspect's own call site.
          optsFor = d: if lib.isFunction d.backup then d.backup pkgs else { };
          targets = lib.filter (d: d.backup or false != false) dataset;
        in
        # No restic jobs at all until `applicationKeyId` is real - see this file's header
        # comment. The bucket itself (`terranix`, below) is unaffected; it's a separate class,
        # not gated on this.
        lib.optionalAttrs (applicationKeyId != null) {
          services.restic.backups = lib.listToAttrs (
            map (
              d:
              lib.nameValuePair d.name (
                {
                  environmentFile = config.age.secrets.backup-b2-env.path;
                  initialize = true;
                  passwordFile = config.age.secrets.backup-restic-password.path;
                  paths = [ "/${d.pool}/${d.name}" ];

                  pruneOpts = [
                    # Must cover at least the 30-day Object Lock retention below (31d for a day of
                    # margin against scheduling jitter/clock skew) - otherwise `forget --prune`
                    # would try to delete pack/snapshot objects B2 is still refusing to delete
                    # (anything younger than 7 days that isn't a weekly/monthly keeper falls in
                    # that gap under keep-daily/weekly/monthly alone), and prune would fail. Every
                    # `--keep-*` rule is OR'd together, so this only ADDS retention on top of the
                    # ones below, never removes it.
                    "--keep-within 31d"
                    "--keep-daily 7"
                    "--keep-weekly 4"
                    "--keep-monthly 6"
                  ];

                  repository = "b2:${bucket}:/";
                  runCheck = true;
                  timerConfig.OnCalendar = "daily";
                }
                // optsFor d
              )
            ) targets
          );

          # restic's own module doesn't order its generated services against anything - each
          # backed-up dataset's own zfs-dataset-<pool>-<name>.service (zfs.nix) must exist first.
          systemd.services = lib.listToAttrs (
            map (
              d:
              lib.nameValuePair "restic-backups-${d.name}" {
                after = [ "zfs-dataset-${d.pool}-${d.name}.service" ];
                requires = [ "zfs-dataset-${d.pool}-${d.name}.service" ];
              }
            ) targets
          );
        };

      secrets = { secrets, ... }: {
        # The B2 application key restic itself uses - an external credential from Backblaze,
        # not something this repo can generate. Author it by hand via `agenix edit
        # secrets/${backupKeySecretName}.age` (Backblaze -> App Keys -> Add a New Application
        # Key, scoped to just THIS host's backup bucket - paired with the plain
        # `applicationKeyId` parameter above, not a second secret), then `agenix rekey -a`.
        # `intermediary` because nothing reads this directly - only the generator below, which
        # folds it into restic's expected B2_ACCOUNT_KEY env var (B2_ACCOUNT_ID comes straight
        # from the plain `applicationKeyId` parameter instead, no decrypt needed for that half).
        #
        # Deliberately NOT the same credential as b2-application-key above - this one is scoped
        # to just this host's backup bucket (least privilege for the thing that runs
        # unattended, daily); that one is a broader, account-level key that only Terraform -
        # run by hand - ever touches.
        ${backupKeySecretName} = {
          intermediary = true;
          rekeyFile = ../../../secrets + "/${backupKeySecretName}.age";
        };

        # An account-level B2 key (bucket/key management capabilities - NOT the narrow,
        # bucket-scoped one below), used ONLY to authenticate the `b2` Terraform provider below.
        # Author it by hand via Backblaze -> App Keys -> Add a New Application Key (no bucket
        # restriction this time, so it can create one - paired with the plain
        # `accountApplicationKeyId` above, not a second secret), then `agenix
        # rekey -a`. `intermediary` because nothing reads this directly - only the generator
        # below, which exposes it under B2_APPLICATION_KEY (modules/terranix.nix derives that
        # env var straight from this secret's own name).
        #
        # Deliberately shared across every host that includes this aspect (no `-${host.name}`
        # suffix) - see this file's header comment for why that's correct here, unlike
        # `backupKeySecretName` below.
        b2-application-key = {
          intermediary = true;
          rekeyFile = ../../../secrets/b2-application-key.age;
          settings.terraform = true;
        };

        backup-b2-env.generator = {
          dependencies.${backupKeySecretName} = secrets.${backupKeySecretName};

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'B2_ACCOUNT_ID=%s\n' ${lib.escapeShellArg applicationKeyId}
              printf 'B2_ACCOUNT_KEY=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.${backupKeySecretName}.file})"
            '';
        };

        backup-restic-password.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 32";
      };

      # `nix run .#harmony-tf.plan` / `.#harmony-tf` - see dns.nix's own header comment for the
      # full command list; same terranix mechanism, just a different provider.
      terranix = {
        # `application_key_id` is set directly (not a secret - see the plain-value comment up
        # top); `application_key` isn't set here at all - the provider reads it from
        # B2_APPLICATION_KEY (the b2-application-key secret above), so nothing sensitive lands in
        # this config or in Terraform state via the provider block itself.
        provider.b2.application_key_id = accountApplicationKeyId;

        resource.b2_bucket.backup = {
          bucket_name = bucket;
          # Nothing in this bucket is meant to be fetched by URL - only ever by restic, which
          # reads it back out using the same application key it writes with.
          bucket_type = "allPrivate";

          # Object Lock: even a fully compromised restic application key (this host's own
          # backup-b2-application-key-<host.name> secret, above) can't delete or overwrite an
          # object during its retention window - governance mode (not compliance) so the
          # account-level key above
          # could still shorten/remove it in a real emergency, rather than being locked out
          # permanently by a misconfiguration.
          file_lock_configuration = [
            {
              default_retention = [
                {
                  mode = "governance";

                  period = [
                    {
                      duration = 30;
                      unit = "days";
                    }
                  ];
                }
              ];

              is_file_lock_enabled = true;
            }
          ];
        };

        terraform.required_providers.b2 = {
          source = "Backblaze/b2";
          version = "0.13.2";
        };
      };
    };
}
