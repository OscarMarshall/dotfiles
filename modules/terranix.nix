# Generic Den <-> terranix wiring: any aspect can contribute a `terranix = {...};` class module
# (same shape as `nixos`/`darwin`/`homeManager`), scoped and merged per-host, turned into a
# `nix run .#<hostname>-tf` / `.#<hostname>-tf.plan` / `nix develop .#<hostname>-tf` Terraform
# workflow. See https://den.denful.dev/tutorials/terranix-demo/.
#
# A `terranix` field that's a FUNCTION requesting a den context arg (`host`, or a quirk like
# `virtual-host`) needs the `warnings-shim` below. Den's `wrapClassModule` attaches a
# collision-validator module (which sets a `warnings` output) to any such function;
# nixos/darwin/homeManager tolerate that fine (real NixOS-derived module types already have a
# `warnings` option), but terranix's own module type (upstream, not den) doesn't declare one, so
# `evalModules` throws "The option `warnings` does not exist" - not because of the value, just
# because nothing declared the option. `warnings-shim` declares it (default `[ ]`) so evaluation
# succeeds; terranix's own core (`core/default.nix`) then builds its final JSON by explicitly
# whitelisting only real Terraform keys (resource/variable/provider/etc.), so the shimmed
# `warnings` value never reaches config.tf.json regardless of its contents.
#
# Exposing a secret to Terraform: set `settings.terraform` on that secret's OWN entry under the
# aspect's `secrets` field (agenix-rekey's `age.secrets.<name>.settings` - a genuinely freeform
# `nullOr attrs` field agenix-rekey declares but never itself reads, so it's safe to use for our
# own bookkeeping - see https://github.com/oddlama/agenix-rekey). No separate quirk or list to keep
# in sync elsewhere; the secret's own declaration is the single source of truth for whether (and
# how) it reaches Terraform:
#
#   settings.terraform = true;        - a provider reads this straight from an env var (e.g.
#                                        Cloudflare's/Meraki's dashboard tokens) - exposed under
#                                        the env var `env-var-for` derives from the secret's OWN
#                                        name (kebab-case -> SCREAMING_SNAKE, e.g.
#                                        `cloudflare-api-token` -> `CLOUDFLARE_API_TOKEN`) - so name
#                                        the secret to match whatever env var the provider actually
#                                        reads.
#   settings.terraform = "variable";  - the value is a RESOURCE ATTRIBUTE (e.g. an OIDC client
#                                        secret Authentik's API has to persist), which nothing in
#                                        Terraform can read from an arbitrary env var - only from a
#                                        declared `variable`, populated via the `TF_VAR_*`
#                                        convention. Exposed as `TF_VAR_<env-var-for name>`; the
#                                        consuming aspect declares `variable.<env-var-for name>` in
#                                        its own `terranix` field and references
#                                        `"\${var.<env-var-for name>}"`.
#
# Every such secret, across every aspect on a host, is collected below into that host's own
# `"${host.name}-tf.env"` generated secret (create/update it like any other generated secret:
# `agenix generate -a && agenix rekey -a`) - `terraformWrapper.prefixText` decrypts and sources it
# automatically before every `nix run .#<hostname>-tf*` invocation, so there's no manual per-secret
# `source <(agenix -d ...)` step to remember (or to add to) when a new aspect starts contributing a
# credential.
#
# `settings.terraform = "variable"` secrets can end up in Terraform's STATE file in plaintext once
# applied (Terraform has to persist resource attributes to manage them - no env-var trick routes
# around that), and state for hosts like harmony is committed to this (public) repo (see
# .gitignore's comment, and #516). `terraform.encryption` below (contributed unconditionally for
# every host) is what actually keeps those out of the plaintext git history.
{
  config,
  lib,
  den,
  inputs,
  ...
}:
let
  # kebab-case -> SCREAMING_SNAKE_CASE, e.g. `cloudflare-api-token` -> `CLOUDFLARE_API_TOKEN`.
  env-var-for = secret: lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] secret);
  # The actual env var a `settings.terraform`-flagged secret surfaces as, per the two modes
  # documented above.
  terraform-env-var-for =
    name: sec: if terraform-mode-of sec == "variable" then "TF_VAR_${env-var-for name}" else env-var-for name;
  # `sec.settings` is a declared option, default `null` - `a.b.c or default` short-circuits the
  # WHOLE chain (not just the last step), so this is safe even when `sec.settings` itself is
  # `null`. Returns `null` for anything not opted in, `true`/`"variable"` (or whatever else
  # `settings.terraform` was set to) otherwise.
  terraform-mode-of = sec: sec.settings.terraform or null;
  # Collects every `settings.terraform`-flagged secret, across every aspect on a host, into that
  # host's own `"${host.name}-tf.env"` generated secret - lives outside any single aspect (like
  # virtual-host.nix/port-forward.nix's consumers) since it's shared plumbing, not owned by any one
  # service. `os` (not `nixos`) so this works identically whichever platform a future
  # terraform-contributing host runs.
  terraform-secrets-aspect =
    { host, ... }:
    let
      dataset-service-name = "zfs-dataset-${terranix-dataset.pool}-${terranix-dataset.name}";
      # `my.terranix` is opt-in (see harmony.nix) - a host only reaches this code by asking for it,
      # and is expected to run `nix run .#<host>-tf.init` once (generating and committing this
      # file) before its first `nixos-rebuild switch`. No `builtins.pathExists` guard: if that
      # step hasn't happened yet, evaluating this host's config should fail loudly on the missing
      # file, the same way referencing a not-yet-`agenix edit`ed secret would - not silently no-op
      # until someone notices the lock file is missing.
      lock-file = ../. + "/${tf-package-name}/.terraform.lock.hcl";
      # Computed here, using the file's own top-level `config` - NOT `nixos`'s own per-host
      # `config` below, which would shadow this one (same trap the `terranix-modules` comment
      # above warns about). `packages.<system>.<name>` is `result.app`'s own passthru
      # (terranix's flake-module.nix), giving the already-built config.tf.json derivation without
      # needing to `nix build`/fetch the flake at apply time. Hardcoded to x86_64-linux, matching
      # `terranix-dataset`'s own "metalminds"/harmony-only scope - no other host runs real
      # Terraform-managed resources today.
      terraform-config-json = config.flake.packages.x86_64-linux.${tf-package-name}.config;
      tf-package-name = "${host.name}-tf";
    in
    {
      # Unconditional: `my.zfs [ "metalminds" ]` is assumed present wherever this dataset actually
      # matters (i.e. on a host with committed Terraform config - today, only harmony has both).
      dataset = terranix-dataset;

      nixos = { pkgs, ... }: {
        systemd.services = {
          # Every other `dataset` consumer in this repo pairs its declaration with a `units`
          # entry - the systemd unit that actually needs the dataset, which is what triggers
          # zfs.nix's `zfs-dataset-<pool>-<name>` ensure-service to run at boot (a bare
          # `dataset` declaration guarantees nothing gets created on its own - see zfs.nix's
          # own comment). `wantedBy` directly is the fallback for a dataset with no such
          # consumer - it makes the ensure-service (and so `zfs create`) run unconditionally at
          # boot instead of never running at all. Safe to assume the real service definition
          # (which `my.zfs`'s own generator - not this file - actually attaches `ExecStart` to)
          # exists here: `my.zfs [ "metalminds" ]` is a prerequisite for `my.terranix` (see the
          # `dataset` field's own comment), and `my.terranix` is opt-in, so only a host that has
          # both ever reaches this code.
          "${dataset-service-name}".wantedBy = [ "multi-user.target" ];

          # Plans whenever the rendered Terraform config (or the lock file) actually changes, and
          # applies only if the plan is destroy-free - Authentik OIDC clients, *arr wiring, etc.
          # aren't things to let an unattended run delete with no human in the loop. A
          # destroy-containing plan (or any other failure) just exits non-zero: no separate
          # alerting wired up here, relying instead on Netdata's stock "failed systemd unit"
          # health check (already routed to Discord via my/netdata.nix's
          # health_alarm_notify.conf) to surface it.
          #
          # `wantedBy` + `restartTriggers` (not a custom `system.activationScripts` entry that
          # `systemctl start`s this directly) - confirmed live: activation scripts run BEFORE
          # `switch-to-configuration` reloads the systemd daemon and registers new/changed unit
          # files, so a direct `systemctl start` from activation hits "Unit ... not found" on the
          # very switch that introduces the unit. `wantedBy` starts it the first time it's ever
          # introduced (and again on every plain boot, via multi-user.target); `restartTriggers`
          # makes ordinary NixOS unit reconciliation - which runs AFTER daemon-reload, so it
          # doesn't hit this bug - restart (equivalent to start, for an inactive oneshot) it on
          # every LATER switch that changes what Terraform would actually do. Trade-off: a switch
          # that changes nothing Terraform-relevant won't re-check for drift introduced entirely
          # outside Nix (e.g. someone editing something by hand in Authentik's UI) - acceptable,
          # since the goal here is "don't need a separate manual apply after a Nix change", not
          # continuous drift detection.
          "${tf-package-name}-apply" = {
            description = "Plan, and apply if safe, ${host.name}'s Terraform-managed infrastructure";
            wantedBy = [ "multi-user.target" ];

            # `network-online.target`: every provider here (Cloudflare, Meraki, Authentik, Mailgun)
            # is a real network call - without this, a boot can reach multi-user.target (and so
            # start this unit) before the network is actually up, failing/flapping on a cold boot
            # even though nothing is actually wrong.
            #
            # `nginx.service`/`authentik.service`: every ON-BOX service any provider here talks to
            # (Sonarr, Radarr, Prowlarr, Jellyfin, Home Assistant, ...) is reached through nginx's
            # reverse proxy, never a raw service port directly - and authentik.service backs both
            # the Authentik provider's own resources AND every service sitting behind Authentik
            # forward-auth. A switch that restarts either (e.g. an authentik.nix config change, or
            # simply the new nginx vhosts a switch like this one adds) used to race this unit:
            # confirmed live on 2026-08-09 - this unit started at 13:01:03, six seconds BEFORE
            # authentik.service even began its own restart (`Started authentik.service` at
            # 13:01:09), so every Authentik-backed resource failed with a 502. Deliberately NOT
            # extended to every individual on-box service's own unit (sonarr.service, jellyfin.service,
            # ...) - that would need updating every time a new terraform-consuming aspect is added;
            # nginx/authentik are the two fixed choke points everything else already routes through.
            # Ordering alone doesn't fully close the gap (a unit reporting "started" doesn't mean
            # its listener is actually accepting connections yet - authentik.service's own gunicorn
            # workers were still booting 4s after systemd called it started) - the retry loop around
            # `tofu plan` below covers the remainder.
            after = [
              "${dataset-service-name}.service"
              "network-online.target"
              "nginx.service"
              "authentik.service"
            ];

            requires = [ "${dataset-service-name}.service" ];

            restartTriggers = [
              terraform-config-json
              lock-file
            ];

            serviceConfig = {
              # `RuntimeDirectory`, not a hand-rolled `/var/lib/<name>` (created/torn down by
              # systemd around each run, at `$RUNTIME_DIRECTORY`): the config/lock symlinks are
              # regenerated identically every run anyway, and - more importantly - `tfplan` below
              # is an OpenTofu plan file, which (unlike state) OpenTofu doesn't encrypt by default;
              # `terraform.encryption.plan` above closes that gap for its CONTENTS, but there's no
              # reason to also let the file linger on disk indefinitely between runs regardless.
              # `CacheDirectory` (persists, unlike RuntimeDirectory - systemd's "safe to delete,
              # will be regenerated" directory type) is only for the downloaded provider plugin
              # cache, kept separate so it survives being wiped every run - re-downloading
              # providers on every switch-triggered apply would be needlessly wasteful.
              CacheDirectory = tf-package-name;

              ExecStart = pkgs.writeShellScript "${tf-package-name}-apply" ''
                set -euo pipefail
                workdir="$RUNTIME_DIRECTORY"
                export TF_PLUGIN_CACHE_DIR="$CACHE_DIRECTORY"
                ln -sf ${terraform-config-json} "$workdir/config.tf.json"
                ln -sf ${lock-file} "$workdir/.terraform.lock.hcl"
                cd "$workdir"
                # `source`d directly (like the wrapper's own prefixText) rather than loaded via
                # systemd's `EnvironmentFile=` - this file's values are `printf %q`-quoted for a
                # real shell to `source`, and systemd's own EnvironmentFile parser isn't guaranteed
                # to agree with bash's `%q` output for every possible value (e.g. its ANSI-C
                # `$'...'` form for unusual bytes) - sourcing it with the same shell that wrote it
                # avoids relying on two parsers agreeing.
                #
                # Fails fast with an explicit message instead of silently continuing, unlike the
                # wrapper's own (interactively-run, human-watched) prefixText:
                # `open-tofu-state-passphrase` is unconditionally `settings.terraform =
                # "variable"`-flagged (see its own comment), so this file is in practice always
                # both present and readable by the time this unit runs (agenix activation
                # decrypts it synchronously during system activation, well before any triggered
                # unit's ExecStart starts) - if it's NOT readable, that's a real, unexpected
                # problem (not a normal transient state), and letting the script fall through into
                # `tofu init`/`plan` would just fail later with a confusing "missing credentials"
                # error instead of pointing at the actual cause.
                decrypted_env_file="/run/agenix/${tf-package-name}.env"
                if [ ! -r "$decrypted_env_file" ]; then
                  echo "Cannot read $decrypted_env_file - secrets not decrypted yet?" >&2
                  exit 1
                fi
                set -a
                # shellcheck disable=SC1090 # dynamic path is intentional - see decrypted_env_file above
                source "$decrypted_env_file"
                set +a
                ${pkgs.opentofu}/bin/tofu init -input=false -lockfile=readonly

                # One full plan -> destroy-check -> apply cycle. Return codes: 0 success, 1 a
                # genuine/possibly-transient failure (safe to retry from a fresh plan), 2 a
                # destroy-containing plan (never retried - see the outer loop below).
                plan_and_apply() {
                  # Retries rather than a single attempt: the `after`/ordering above (this unit's
                  # own comment) only guarantees nginx.service/authentik.service have been TOLD to
                  # start, not that they're actually accepting connections yet - a plan run moments
                  # after either restarts can still hit a live 502/connection-refused window.
                  # `until` (not `if`/`&&`) so a failing `tofu plan` doesn't trip `set -e` on its
                  # own. `-parallelism=1`: Jellyfin's own API isn't concurrency-safe for
                  # plugin-management calls - see the interactive wrapper's own `prefixText` (this
                  # file, `perSystem` below) for the confirmed-live failure this avoids.
                  plan_attempt=1
                  plan_max_attempts=5
                  until ${pkgs.opentofu}/bin/tofu plan -input=false -parallelism=1 -out=tfplan; do
                    if [ "$plan_attempt" -ge "$plan_max_attempts" ]; then
                      echo "tofu plan failed after $plan_max_attempts attempts" >&2
                      return 1
                    fi
                    echo "tofu plan failed (attempt $plan_attempt/$plan_max_attempts) - retrying in 10s..." >&2
                    plan_attempt=$((plan_attempt + 1))
                    sleep 10
                  done
                  # Explicitly checked, NOT a plain assignment relying on `set -e` to catch a
                  # `tofu show`/`jq` failure: this function is called as `plan_and_apply ||
                  # cycle_status=$?` below, and bash disables `-e` for a compound command's ENTIRE
                  # execution - including everything inside a function it calls - whenever that
                  # compound command sits on the left of `||` (or `&&`, or an `if`/`while`
                  # condition). A bare `has_destroy="$(...)"` here would silently swallow a
                  # show/jq failure as `has_destroy=""`, read as a false "no destroys", and fall
                  # through to `tofu apply` on a plan this never actually inspected - defeating the
                  # entire guard below. `if ! has_destroy=...; then` tests the substitution's exit
                  # status directly instead.
                  if ! has_destroy="$(
                    ${pkgs.opentofu}/bin/tofu show -json tfplan \
                      | ${pkgs.jq}/bin/jq '[.resource_changes[]?.change.actions[]?] | any(. == "delete")'
                  )"; then
                    echo "tofu show/jq failed while checking the plan for destroy actions" >&2
                    return 1
                  fi
                  if [ "$has_destroy" = true ]; then
                    echo 'Plan contains destroy actions - refusing to auto-apply; review manually with `nix run .#${tf-package-name}.plan`.' >&2
                    return 2
                  fi
                  ${pkgs.opentofu}/bin/tofu apply -input=false -parallelism=1 tfplan
                }

                # Outer retry around the WHOLE cycle, not just `apply`: a saved plan goes stale the
                # moment ANY of its resources actually applies (OpenTofu refuses to re-apply a plan
                # file once state has moved past what it was computed against), so recovering from
                # a mid-apply failure needs a brand new plan reflecting whatever DID get created,
                # not a re-run of the same plan file. Confirmed live: jellyfin_plugin.moonbase timed
                # out waiting 30s for Jellyfin to register a just-installed plugin ("plugin
                # \"Moonbase\" did not appear within 30s") while two sibling resources in the SAME
                # apply succeeded seconds later - ordinary transient slowness (Jellyfin background
                # work, a slow fetch), not a structural bug, so simply trying again from a fresh
                # plan is the right recovery. `plan_and_apply || cycle_status=$?` (not testing the
                # call directly) is the standard way to capture a function's real exit code without
                # tripping `set -e` - see the loop's own body for why `if ! ...` wouldn't preserve
                # the distinction between return codes 1 and 2 here.
                apply_attempt=1
                apply_max_attempts=3
                while true; do
                  cycle_status=0
                  plan_and_apply || cycle_status=$?
                  if [ "$cycle_status" -eq 0 ]; then
                    break
                  fi
                  if [ "$cycle_status" -eq 2 ]; then
                    exit 1
                  fi
                  if [ "$apply_attempt" -ge "$apply_max_attempts" ]; then
                    echo "plan/apply cycle failed after $apply_max_attempts attempts" >&2
                    exit 1
                  fi
                  echo "plan/apply cycle failed (attempt $apply_attempt/$apply_max_attempts) - retrying with a fresh plan in 15s..." >&2
                  apply_attempt=$((apply_attempt + 1))
                  sleep 15
                done
              '';

              RuntimeDirectory = tf-package-name;
              Type = "oneshot";
            };

            wants = [ "network-online.target" ];
          };
        };
      };

      secrets =
        {
          config,
          lib,
          secrets,
          ...
        }:
        let
          terraform-secrets = lib.filterAttrs (_: sec: terraform-mode-of sec != null) config.age.secrets;
        in
        {
          # This key's PRESENCE must be unconditional, even though `terraform-secrets` (its VALUE
          # depends on it) is empty exactly when only `open-tofu-state-passphrase` above is
          # flagged - making it conditional on `terraform-secrets != { }` would mean
          # `config.age.secrets`'s own key set depends on whether THIS module contributes this SAME
          # key, which depends on scanning `config.age.secrets`'s key set - "infinite recursion
          # encountered". A value may safely depend on the fully-merged `config.age.secrets` (lazy
          # evaluation handles that fine); a key's PRESENCE may not.
          "${host.name}-tf.env".generator = {
            dependencies = lib.mapAttrs (name: _: secrets.${name}) terraform-secrets;

            script =
              {
                lib,
                decrypt,
                deps,
                ...
              }:
              lib.concatMapStrings (name: ''
                # %q (not a plain "%s") shell-quotes the decrypted value before it lands in the
                # generated env file - this file gets `source`d (see terraformWrapper.prefixText
                # below), so an unescaped value containing `$`, backticks, `\`, or `"` would be
                # reinterpreted by the shell instead of reproduced literally.
                printf '${terraform-env-var-for name terraform-secrets.${name}}=%q\n' "$(${decrypt} ${
                  lib.escapeShellArg deps.${name}.file
                })"
              '') (lib.attrNames terraform-secrets);
          };

          # Always present (not left to opt in) - it backs `terraform.encryption` below, which every
          # `<host>-tf` gets unconditionally (see that field's own comment for why).
          open-tofu-state-passphrase = {
            generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 32";
            intermediary = true;
            settings.terraform = "variable";
          };
        };

      # Encrypts every `<host>-tf` state/plan at rest (OpenTofu's built-in state encryption, stable
      # since 1.8 - pinned opentofu is 1.12.3) - added repo-wide here, not per-aspect, since ANY
      # aspect's `terranix` field can start carrying a secret-bearing resource attribute (the
      # `settings.terraform = "variable"` convention above exists precisely for that), and state for
      # hosts like harmony is committed to this (public) repo (see .gitignore's comment, and #516).
      # Unconditional (not gated on whether any `settings.terraform` secret actually exists) because
      # this field can't see `config.age.secrets` to gate itself on - it's evaluated in terranix's
      # own module-type pass, which only den quirks bridge into (see this file's header comment), and
      # `age.secrets` isn't one.
      terranix = {
        # Points state at the `terranix` dataset (declared above) instead of the default
        # cwd-relative `terraform.tfstate` the wrapper's workdir would otherwise use - state is
        # runtime output of applying config, not config itself, so it doesn't belong in git (see the
        # dataset declaration's own comment). Changing this on a host with existing state requires a
        # one-time `tofu init -migrate-state` to move it, done by hand - not something to let happen
        # implicitly on a routine apply.
        backend.local.path = "/metalminds/terranix/terraform.tfstate";

        terraform.encryption = {
          key_provider.pbkdf2.main.passphrase = "\${var.OPEN_TOFU_STATE_PASSPHRASE}";
          method.aes_gcm.main.keys = "\${key_provider.pbkdf2.main}";
          # Plan encryption is a SEPARATE opt-in from state encryption above - without this,
          # `tofu plan -out=tfplan` (used by the apply-automation service) writes a fully plaintext
          # plan file to disk, defeating the whole point of encrypting state: a plan's resource
          # diff carries the same `settings.terraform = "variable"` secret values state does. No
          # `fallback` for the same reason `state` has none - plans are never persisted anywhere
          # that could hold a pre-existing plaintext one to migrate.
          plan.method = "method.aes_gcm.main";
          # `method` is a STATIC TRAVERSAL, not a computed value - HCL's JSON spec requires this as
          # a plain string containing raw HCL syntax (`"method.aes_gcm.main"`), NOT a `"\${...}"`
          # template - the latter parses as a template expression and fails validate ("A single
          # static variable reference is required ... No ... template expressions ... allowed
          # here"), even though `"\${...}"` is exactly right for genuinely computed values elsewhere
          # in this block (`key_provider.pbkdf2.main.passphrase`, `aes_gcm.main.keys`).
          #
          # No `fallback` (used to be `method.unencrypted.migrate`, a no-op key_provider that only
          # existed to give a migration fallback something to name) - that was for reading every
          # `<host>-tf/terraform.tfstate` committed before this feature landed (e.g. harmony's, from
          # #516), which was still plaintext JSON. harmony's has since been migrated (confirmed: same
          # lineage, same resources, now `encrypted_data`) and no other host has an existing state to
          # migrate - a first-ever apply just starts encrypted. Removed rather than left in
          # permanently: OpenTofu warns ("Unencrypted method configured ... security risk") on every
          # plan/apply for as long as it's configured, which is only accurate while it's actually
          # protecting a real migration. If a host ever needs it again (e.g. restoring a plaintext
          # state from backup), re-add `method.unencrypted.migrate = { };` and
          # `state.fallback.method = "method.unencrypted.migrate";` temporarily.
          state.method = "method.aes_gcm.main";
        };

        variable.OPEN_TOFU_STATE_PASSPHRASE.sensitive = true;
      };
    };
  # State (e.g. `harmony-tf/terraform.tfstate`) is runtime output of applying config, not config
  # itself, so - unlike everything else in this repo - it doesn't belong in git history (no
  # meaningful diff to review, especially encrypted; only ever moves forward). This dataset gives
  # it a stable, host-local home with the same backup/snapshot coverage as every other ZFS-backed
  # service here, once the wrapper's backend `path` is pointed at it instead of the repo checkout.
  terranix-dataset = {
    name = "terranix";
    pool = "metalminds";
  };
  # Read from the file's own top-level `config` (closed over here, not re-requested) for the same
  # reason dns.nix's `perSystem` does the same for `config.flake.nixosConfigurations`: `config` is
  # ALSO the name flake-parts binds to each per-system module's own (different) result, so if
  # `perSystem` below ever needs a per-system `config` of its own again, requesting it there would
  # silently shadow this outer one instead of erroring, making `.flake.terranixModules` resolve to
  # `{ }` and silently dropping every `<hostname>-tf` package. Hoisting the lookup here keeps that
  # failure mode from resurfacing if that happens.
  terranix-modules = config.flake.terranixModules or { };
  warnings-shim = {
    options.warnings = lib.mkOption {
      default = [ ];
      type = lib.types.listOf lib.types.str;
    };
  };
in
{
  flake-file.inputs.terranix = {
    url = "github:terranix/terranix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [ (inputs.terranix.flakeModule or { }) ];

  den = {
    classes.terranix = { };

    policies.host-to-terranix = { host, ... }: [
      (den.lib.policy.instantiate {
        class = "terranix";
        instantiate = { modules, ... }: modules;

        # `-tf` suffix (rather than the bare host name) avoids colliding with the
        # `packages.<host>` each host already gets from Den's `nh` battery (quick-rebuild
        # shortcuts) - terranix's flake-module keys `packages.<system>.<key>` off this same
        # intoAttr name.
        intoAttr = [
          "terranixModules"
          "${host.name}-tf"
        ];

        name = "${host.name}-tf";
      })
    ];
  };

  # Exposed as an opt-in `my.*` aspect (included like any other in a host's own `includes` - see
  # harmony.nix) rather than a `den.schema.host.includes` default: `my.zfs [ "metalminds" ]` is a
  # real prerequisite for this (the dataset/state-backend/apply-automation pieces all assume it -
  # see their own comments), so only a host that actually opts into both should get either.
  my.terranix.includes = [
    den.policies.host-to-terranix
    terraform-secrets-aspect
  ];

  # Guarded on `inputs ? terranix`: the first `nix run .#write-flake` pass after adding this
  # module runs before flake.nix/flake.lock actually have a `terranix` input, so the option this
  # sets (declared by terranix's own flakeModule, imported above) doesn't exist yet either.
  perSystem =
    { pkgs, ... }:
    lib.optionalAttrs (inputs ? terranix) {
      terranix.terranixConfigurations = lib.mapAttrs (
        key: modules:
        let
          # Every entry here is keyed `"${host.name}-tf"` (see `intoAttr` above), so stripping the
          # suffix recovers the host name without needing `host` itself in this scope.
          host-name = lib.removeSuffix "-tf" key;
        in
        {
          modules = modules ++ [ warnings-shim ];

          terraformWrapper = {
            package = pkgs.opentofu;

            # Reads the ALREADY-decrypted copy at `/run/agenix/<name>` rather than decrypting the
            # raw secret itself - standard NixOS agenix activation puts every `age.secrets` entry
            # there automatically, using the host's OWN SSH key (`age.identityPaths`, e.g.
            # /etc/ssh/ssh_host_ed25519_key), same as every other secret the host already decrypts
            # unattended at boot. This only works ON the host the secret belongs to (e.g.
            # `nix run .#harmony-tf` run on harmony itself, never off-host) - state now lives on
            # that host's own ZFS dataset too (see `terranix-dataset`/`backend.local.path` above),
            # so there's no longer a reason to support running this anywhere else.
            #
            # `-r`, not `-f`: `open-tofu-state-passphrase` is unconditionally
            # `settings.terraform = "variable"`-flagged (see its own comment), so this file is in
            # practice always generated for every host - the real gap this guards is the file
            # existing but not yet being READABLE (e.g. run before this host's own agenix
            # activation has decrypted it), where `-f` would pass and `source` would fail with a
            # confusing permission error instead of cleanly skipping.
            prefixText = ''
              # Jellyfin's own API isn't concurrency-safe for plugin-management calls - confirmed
              # live: two plugin installs running in the same parallel plan/apply raced Jellyfin's
              # OWN file I/O reading another plugin's icon file ("The process cannot access the
              # file '.../Fanart_14.0.0.0/jellyfin-plugin-fanart.png' because it is being used by
              # another process", surfaced as a `GET /Packages` 500). `TF_CLI_ARGS_plan`/`_apply`/
              # `_destroy` are OpenTofu/Terraform's own env vars for auto-appending flags to those
              # subcommands - serializing ALL resource operations, including destroy (not just
              # Jellyfin's) is coarser than necessary, but this repo's whole config is small enough
              # that the slowdown is negligible, and it closes off the same class of bug for any
              # other on-box API this config talks to concurrently in the future. Appended (not
              # assigned outright) in case a caller already set one of these themselves - dropping
              # whatever flags they asked for out from under them would be a worse surprise than
              # this being merely coarse.
              export TF_CLI_ARGS_apply="''${TF_CLI_ARGS_apply:-} -parallelism=1"
              export TF_CLI_ARGS_destroy="''${TF_CLI_ARGS_destroy:-} -parallelism=1"
              export TF_CLI_ARGS_plan="''${TF_CLI_ARGS_plan:-} -parallelism=1"

              decrypted_env_file="/run/agenix/${host-name}-tf.env"
              if [ -r "$decrypted_env_file" ]; then
                set -a
                # shellcheck disable=SC1090 # dynamic path is intentional - see decrypted_env_file above
                source "$decrypted_env_file"
                set +a
              fi
            '';
          };
        }
      ) terranix-modules;
    };
}
