let
  domain = "silverlight-nex.us";
in
{
  my.nextcloud =
    {
      global ? false,
    }:
    { host, ... }:
    let
      url = "nextcloud.${host.name}.${domain}";
    in
    {
      dataset = {
        pool = "metalminds";
        name = "nextcloud";
      };

      virtual-host = {
        name = "nextcloud";
        host = host.name;
        inherit global;
        # Deliberately no `port` — Nextcloud is PHP-FPM, not a plain HTTP service to
        # proxy_pass to. The quirk emits only forceSSL/enableACME for this vhost, and
        # Nextcloud's own module below supplies its `locations`/`root`, merging cleanly.
        #
        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Per user_oidc's own callback route (and
        # Authentik's Nextcloud integration guide) - `/index.php/...` only matters for installs
        # that haven't set `overwriteprotocol`-style pretty URLs, which this one has (see
        # `settings.overwriteprotocol` below).
        oidc = {
          redirect-paths = [ "/apps/user_oidc/code" ];
          client-secret = "nextcloud-oidc-client-secret";
        };
        label = "Nextcloud";
        icon = "nextcloud.svg";
        group = "Media";
        homepage = {
          description = "Files, calendar & office suite";
        };
      };

      secrets = {
        nextcloud-admin-password.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 24";
        # `settings.terraform = "variable";` feeds a Terraform `variable` (modules/terranix.nix's
        # two modes); also read directly below (LoadCredential) to configure user_oidc via occ, so
        # it's NOT `intermediary` - it has to be materialized as a real host secret too.
        nextcloud-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          settings.terraform = "variable";
        };
      };

      nixos = { config, pkgs, ... }: {
        services.nextcloud = {
          enable = true;
          hostName = url;
          https = true;
          package = pkgs.nextcloud33;

          database.createLocally = true;
          config = {
            dbtype = "pgsql";
            adminuser = "admin";
            adminpassFile = config.age.secrets.nextcloud-admin-password.path;
          };

          datadir = "/metalminds/nextcloud"; # holds both config/ (config.php) and data/ (user files)

          extraApps = with config.services.nextcloud.package.packages.apps; {
            inherit user_oidc richdocuments;
          };

          settings = {
            overwriteprotocol = "https";
            # Drops the username/password form from /login, leaving just the "Log in with
            # Authentik" button - the alternative-logins block sits OUTSIDE the form's `v-if` in
            # core's Login.vue, so SSO survives being hidden.
            #
            # This is friction, not a security boundary, and Nextcloud means it that way: the same
            # view re-renders the form for `?direct=1`, so /login?direct=1 remains the way in for
            # the local `admin` account if Authentik is ever down. Little is lost by that - the
            # OIDC-provisioned accounts have no password to type in the first place (user_oidc is
            # their backend), so `admin` was already the only account a form could authenticate.
            hide_login_form = true;
          };
        };

        # Wires user_oidc -> Authentik and richdocuments -> Collabora post-install, since
        # neither app exposes a declarative option surface (both are app-level DB state
        # configured via occ).
        systemd.services.nextcloud-authentik-richdocuments-setup = {
          description = "Configure Nextcloud OIDC (Authentik) and richdocuments (Collabora) via occ";
          after = [
            "nextcloud-setup.service"
            "coolwsd.service"
            "nginx.service"
          ];
          requires = [ "nextcloud-setup.service" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "oneshot";
            User = "nextcloud";
            LoadCredential = "oidc-client-secret:${config.age.secrets.nextcloud-oidc-client-secret.path}";
          };

          path = [ config.services.nextcloud.occ ];

          script = ''
            set -euo pipefail

            # `user_oidc:provider` is an UPSERT keyed on the identifier - its own class is
            # `UpsertProvider`, and it calls `createOrUpdateProvider()` - so it needs no
            # create-vs-update branch. There is no `--update` option (passing one aborts the whole
            # unit before it can correct anything), which is worth stating because getting this
            # wrong FAILS SILENTLY in the worst way: the very first run creates the provider and
            # succeeds, and only later runs - the ones meant to carry a changed `discoveryuri` or a
            # rotated secret into Nextcloud - die, leaving a provider frozen at whatever the first
            # run happened to write. That's exactly how Nextcloud ended up pointing at Authentik's
            # old pre-`global` hostname, which no longer resolves, and reporting only "Could not
            # reach the OpenID Connect provider" at login.
            #
            # `--clientsecret-file` rather than `--clientsecret`: the latter would put the secret in
            # this unit's argv, briefly readable via /proc/<pid>/cmdline by any local user. occ reads
            # and trims the file itself.
            #
            # `--unique-uid=0` turns OFF user_oidc's default of hashing identifiers
            # (`LocalIdService.getId`: sha256 of "<providerId>_0_<id>" when it's on, the raw value
            # when it's off). It governs GROUP gids as much as user ids, so it's what makes both of
            # the settings below land as readable names rather than hex. Flipping it later
            # re-identifies everyone - existing accounts become unreachable and log in as new,
            # empty ones - so it's effectively permanent once anyone has files.
            #
            # `--mapping-uid=preferred_username` is required alongside it: the uid claim defaults to
            # `sub` (`SETTING_MAPPING_UID_DEFAULT`), which authentik derives as a hash
            # (`sub_mode = hashed_user_id`), so `--unique-uid=0` alone would just swap our hash for
            # authentik's. Authentik's default `profile` scope supplies `preferred_username`.
            #
            # `--group-provisioning=1` syncs Nextcloud group membership from the `groups` claim on
            # each login, and it's AUTHORITATIVE: user_oidc removes an OIDC user from any group
            # absent from the claim, so don't hand-assign groups to these accounts - Authentik is
            # the only place that sticks. This is also what grants admin, without a mapping layer:
            # user_oidc creates each group under the claim value verbatim, and Nextcloud confers
            # administrator rights on exactly the group whose gid is `admin` - hence that group
            # being singular in authentik.nix. The local `admin` account is untouched by any of
            # this (it never logs in through OIDC) and stays the way back in.
            #
            # Values are literal 0/1: occ coerces every boolean setting with `$value === '0' ? '0' :
            # '1'`, so `false` would silently mean TRUE.
            nextcloud-occ user_oidc:provider "authentik" \
              --clientid="nextcloud" \
              --clientsecret-file="$CREDENTIALS_DIRECTORY/oidc-client-secret" \
              --discoveryuri="https://${config.services.authentik.nginx.host}/application/o/nextcloud/.well-known/openid-configuration" \
              --scope="openid email profile" \
              --unique-uid=0 \
              --mapping-uid=preferred_username \
              --mapping-groups=groups \
              --group-provisioning=1

            nextcloud-occ config:app:set richdocuments wopi_url --value="http://[::1]:9980"
            nextcloud-occ config:app:set richdocuments public_wopi_url --value="https://collabora.${host.name}.${domain}"
            nextcloud-occ config:app:set richdocuments wopi_allowlist --value="::1,127.0.0.1"
          '';
        };
      };
    };
}
