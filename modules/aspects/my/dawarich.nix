# Dawarich: self-hosted Google Timeline replacement (location history, visits, trips, stats). Runs
# from nixpkgs' native `services.dawarich` module - Postgres/PostGIS and Redis are created locally
# by it - with login handed to Authentik over native OIDC (`virtual-host.oidc` below).
#
# No `global` alias, unlike immich.nix/paperless.nix: Dawarich's OIDC client takes exactly one
# fixed redirect URI, and OmniAuth keeps its `state` in the session cookie of whichever hostname
# started the login - starting on a second name would land the callback on a host with no such
# cookie and fail the CSRF check. Same one-canonical-name reasoning as storyteller.nix's `url`.
{
  my.dawarich =
    { host, ... }:
    let
      port = 3010; # module default 3000 is headplane's
      # Every unit that touches Dawarich's state directory - see the `BindPaths` below.
      units = [
        "dawarich-admin"
        "dawarich-init-db"
        "dawarich-sidekiq-all"
        "dawarich-web"
      ];
      url = "dawarich.${host.name}.${host.domain}";
    in
    {
      # The package hardcodes `/var/lib/dawarich` as Rails' `storage/` (a symlink baked into the
      # store path), which is where ActiveStorage keeps uploaded imports (e.g. Google Takeout
      # files) and generated exports. Rather than leave that on the root disk outside every backup,
      # each unit bind-mounts this dataset over it inside its own mount namespace (`BindPaths`
      # below - the module already sets `PrivateMounts`).
      dataset = {
        inherit units;

        # Points/visits/trips live in Postgres, not here - dump it in before every backup run,
        # same shape as paperless.nix's own DB dump (see nextcloud.nix for the umask reasoning).
        backup = { config, pkgs, ... }: {
          backupCleanupCommand = "rm -f /metalminds/dawarich/.backup/db.sql";

          backupPrepareCommand = ''
            umask 077
            mkdir -p /metalminds/dawarich/.backup
            ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/pg_dump dawarich > /metalminds/dawarich/.backup/db.sql
          '';
        };

        group = "dawarich";
        name = "dawarich";
        pool = "metalminds";
        user = "dawarich";
      };

      nixos = { config, lib, ... }: {
        services.dawarich = {
          enable = true;
          # nginx.nix already reverse-proxies every vhost; Rails serves `public/` itself in
          # production (`public_file_server.enabled = true` upstream), so nothing is lost.
          configureNginx = false;

          environment = {
            # Password login stays off: the module's `rails db:seed` creates an admin
            # `demo@dawarich.app` with a publicly documented password on a fresh database (see
            # `dawarich-admin` below). With OIDC configured this also blocks the API's own
            # password sign-in, so phone trackers authenticate with a user's API key instead.
            ALLOW_EMAIL_PASSWORD_LOGIN = "false";
            ALLOW_EMAIL_PASSWORD_REGISTRATION = "false";
            # Anyone Authentik lets through (the "Media" group below - every household user) gets
            # their own separate timeline on first login.
            OIDC_AUTO_REGISTER = "true";
            # Must equal this vhost's `name` - authentik.nix sets every `oidc` provider's
            # `client_id` to it. Secret comes from `dawarich.env` below, not here (world-readable
            # store).
            OIDC_CLIENT_ID = "dawarich";
            # Trailing slash matters: discovery checks this against the document's `issuer` byte
            # for byte, and Authentik's carries one (same as autobrr.nix/immich.nix).
            OIDC_ISSUER = "https://${config.services.authentik.nginx.host}/application/o/dawarich/";
            OIDC_PROVIDER_NAME = "Authentik";
            OIDC_REDIRECT_URI = "https://${url}/users/auth/openid_connect/callback";
          };

          extraEnvFiles = [ config.age.secrets."dawarich.env".path ];
          localDomain = url;
          # Must be an agenix path, not the module's default of generating one into
          # /var/lib/dawarich/secrets: with the bind mount above, that would land inside the
          # dataset - and in its offsite backups - where it has no business being.
          secretKeyBaseFile = config.age.secrets.dawarich-secret-key-base.path;
          webPort = port;
        };

        systemd.services =
          lib.genAttrs units (_: {
            serviceConfig.BindPaths = [ "/metalminds/dawarich:/var/lib/dawarich" ];
          })
          // {
            # Makes the first person to log in through Authentik Dawarich's admin (OIDC
            # auto-registration always creates plain users), once - same "first account is the
            # admin" model as Immich. Also scrambles the seeded demo admin's documented password,
            # so it stays dead even if password login is ever turned back on. Reuses the
            # module's own migration unit's environment, credentials and sandboxing wholesale;
            # it runs at boot/rebuild, so after the very first login run
            # `systemctl start dawarich-admin` (or just wait for the next rebuild).
            dawarich-admin = {
              inherit (config.systemd.services.dawarich-init-db) path;
              description = "Dawarich admin bootstrap";
              wantedBy = [ "dawarich.target" ];
              after = [ "dawarich-init-db.service" ];
              # NixOS derives PATH from `path` and ExecStart from `script` on every unit - copying
              # init-db's own would define both twice.
              environment = removeAttrs config.systemd.services.dawarich-init-db.environment [ "PATH" ];
              requires = [ "dawarich-init-db.service" ];

              script = ''
                export SECRET_KEY_BASE="$(systemd-creds cat SECRET_KEY_BASE)"
                rails runner '
                  demo = User.find_by(email: "demo@dawarich.app")
                  demo.update!(password: SecureRandom.hex(32)) if demo&.valid_password?("safepassword")

                  unless User.exists?(admin: true, provider: "openid_connect")
                    User.where(provider: "openid_connect").order(:id).first&.update!(admin: true)
                  end
                '
              '';

              serviceConfig = removeAttrs config.systemd.services.dawarich-init-db.serviceConfig [ "ExecStart" ];
            };
          };
      };

      secrets = { secrets, ... }: {
        # Fed to Authentik as a Terraform `variable` (authentik.nix's `oidc`-tagged provider) and
        # read by Dawarich only through `dawarich.env` below, i.e. only at generation time - so
        # `intermediary`, same as beszel.nix's `beszel-password`.
        dawarich-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = "variable";
        };

        # Loaded via systemd credentials, so root ownership is fine.
        dawarich-secret-key-base.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 64";

        # Dawarich has no `_FILE` variant for its OIDC secret, so it goes in through the module's
        # `extraEnvFiles`. Owned by `dawarich` because the module's `dawarich-rails`/
        # `dawarich-console` wrappers also `source` it as that user (systemd reads it as root for
        # the services themselves).
        "dawarich.env" = {
          generator = {
            dependencies = { inherit (secrets) dawarich-oidc-client-secret; };

            script =
              {
                lib,
                decrypt,
                deps,
                ...
              }:
              ''
                printf 'OIDC_CLIENT_SECRET=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.dawarich-oidc-client-secret.file})"
              '';
          };

          group = "dawarich";
          owner = "dawarich";
        };
      };

      virtual-host = {
        inherit port;
        group = "Media";
        homepage.description = "Location history & timeline";
        host = host.name;
        icon = "dawarich.svg";
        label = "Dawarich";
        # Google Takeout location exports can run to hundreds of MB.
        maxBodySize = "5000M";
        name = "dawarich";

        oidc = {
          client-secret = "dawarich-oidc-client-secret";
          redirect-paths = [ "/users/auth/openid_connect/callback" ];
        };

        # Live map/import progress over ActionCable.
        websockets = true;
      };
    };
}
