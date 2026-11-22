{ lib, ... }:
let
  port = 2283;
in
{
  my.immich =
    {
      administrators,
      global ? false,
    }:
    { host, ... }:
    let
      url = "immich.${host.name}.${host.domain}";
    in
    {
      # Owned by `services.immich`'s own user/group (`immich`, which both containers below run as) -
      # zfs.nix's generic `dataset`-quirk consumer chowns it once created, and `units` orders both
      # containers after that (avoids either starting before this exists/is mounted - see zfs.nix's
      # own comment on why that's a real risk).
      dataset = {
        # Immich's blobs live in this dataset but its Postgres DB (services.immich.database,
        # default-enabled, database name "immich") doesn't - a files-only backup would lose all
        # metadata/albums/faces without it, so dump it into the dataset right before every backup
        # run and remove the dump again after. Same shape as nextcloud.nix's own DB dump - see
        # its comment for the umask reasoning. `.backup/` (hidden) rather than a plain
        # subdirectory: Immich only scans this location via its own upload workflow, not as an
        # External Library import path, so a dotfile here is never treated as media - but hidden
        # anyway, in case that ever changes.
        backup = pkgs: {
          backupCleanupCommand = "rm -f /metalminds/pictures/.backup/db.sql";

          backupPrepareCommand = ''
            umask 077
            mkdir -p /metalminds/pictures/.backup
            ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump immich > /metalminds/pictures/.backup/db.sql
          '';
        };

        group = "immich";
        guestAccess = true;
        name = "pictures";
        pool = "metalminds";
        samba = true;

        units = [
          "podman-immich-machine-learning"
          "podman-immich-server"
        ];

        user = "immich";
      };

      # Noodle Gallery (github.com/open-noodle/gallery) rather than upstream Immich - a soft fork
      # (adds family/partner sharing and shared face recognition) that its own docs pitch as a
      # drop-in: same database schema, same media layout, same config file, same mobile/OAuth
      # endpoints. Run from the fork's own images rather than built from source on top of nixpkgs'
      # `immich` derivation: that build is pinned to nixpkgs' exact Immich release, so it only
      # worked while a Noodle release's Immich base happened to match it, and every fork feature
      # that changed the build layout (its extra ML dependency, its second workflow plugin) needed
      # more glue here. The images are what the fork itself tests and ships.
      #
      # `services.immich` stays enabled for everything around the app - Postgres with VectorChord
      # and its extension setup/reindex SQL, the Redis instance, the `immich` user, the media
      # directory's permissions - and its own `environment`/`settings` are reused verbatim below.
      # Only its two app units are switched off and replaced by the containers.
      nixos =
        { config, utils, ... }:
        let
          cfg = config.services.immich;

          # Both run as the host's own `immich` user (uid/gid pinned below), on the host network:
          # Postgres authenticates the server by peer (unix socket, OS user == role), every file
          # it writes into the media dataset keeps its existing owner, and the server reaches ML
          # at `localhost:3003` exactly as the native units did.
          common = {
            extraOptions = [ "--network=host" ];
            user = "${toString config.users.users.immich.uid}:${toString config.users.groups.immich.gid}";
          };
        in
        {
          services.immich = {
            inherit port;
            enable = true;
            host = "127.0.0.1";
            # Replaced by the `immich-machine-learning` container below.
            machine-learning.enable = false;
            mediaLocation = "/metalminds/pictures";

            settings = {
              oauth = {
                # Skip Immich's own login page and bounce straight to Authentik - there's nothing else
                # to pick from it now that `passwordLogin` is off below. `/auth/login?autoLaunch=0`
                # (also `?password=1`) still renders the form instead of redirecting, which is how to
                # reach it if password login ever gets temporarily turned back on to recover.
                autoLaunch = true;
                clientId = "immich";
                clientSecret._secret = config.age.secrets.immich-oidc-client-secret.path;
                enabled = true;
                issuerUrl = "https://${config.services.authentik.nginx.host}/application/o/immich/";
                mobileOverrideEnabled = true;
                mobileRedirectUri = "https://${url}/api/oauth/mobile-redirect";
                scope = "openid email profile";
              };

              # Authentik is the only way in; Immich's own local accounts can no longer be used.
              # Immich attaches an OAuth login to an existing account by EMAIL (its auth service
              # looks the user up with `getByEmail`, then stamps the `oauthId` onto that row), so
              # whoever administers this has to carry the same address in Authentik as on their
              # Immich account - otherwise `autoRegister` (on by default, not set here) quietly
              # makes them a SECOND, non-admin user instead of logging them into the existing one.
              #
              # Not a lockout risk despite that: `services.immich.settings` being set at all puts
              # Immich in config-file mode, where the admin UI can't override any of this anyway, so
              # the way back is flipping this line and rebuilding - not clicking through a UI that
              # would refuse anyway.
              passwordLogin.enabled = false;
            };
          };

          systemd = {
            services = {
              # Replaced by the `immich-server` container below. Disabling the unit (rather than the
              # whole module) keeps everything else `services.immich` sets up; nothing builds
              # `cfg.package` any more, since only this unit referenced it.
              immich-server.enable = false;

              podman-immich-server = {
                after = [
                  "postgresql.target"
                  "redis-immich.service"
                ];

                # The native unit's own config-file step (`settings` -> JSON, `_secret`s filled in),
                # moved here since that unit no longer runs. Written as root, handed to `immich`. The
                # directory is made here rather than with `RuntimeDirectory`, which oci-containers
                # already sets on this unit for itself.
                preStart = ''
                  install -d -m 755 ${dirOf cfg.environment.IMMICH_CONFIG_FILE}
                  umask 077
                  ${(utils.genJqSecretsReplacement { } cfg.settings cfg.environment.IMMICH_CONFIG_FILE).script}
                  chown immich:immich ${cfg.environment.IMMICH_CONFIG_FILE}
                '';

                requires = [
                  "postgresql.target"
                  "redis-immich.service"
                ];
              };
            };

            # Was the native ML unit's `CacheDirectory` - kept for its already-downloaded models.
            tmpfiles.settings.immich."/var/cache/immich".d = {
              group = "immich";
              mode = "0700";
              user = "immich";
            };
          };

          users = {
            # Pinned to the ids harmony's NixOS already allocated (read live with `id immich`/`getent
            # group redis-immich`) - the containers need them as numbers, and NixOS never changes an
            # existing user's uid anyway, so any other value would just leave the containers running
            # as a different user than the one owning the media and the Postgres role.
            groups = {
              immich.gid = 979;
              # So the server container can open Redis' unix socket (mode 660, this group).
              redis-immich.gid = 978;
            };

            users =
              lib.genAttrs administrators (user: {
                extraGroups = [ "immich" ];
              })
              // {
                immich.uid = 982;
              };
          };

          virtualisation.oci-containers.containers = {
            immich-machine-learning = common // {
              environment = {
                IMMICH_HOST = "127.0.0.1";
                IMMICH_PORT = "3003";
                # Same as nixpkgs' native unit, which this replaces.
                MACHINE_LEARNING_WORKERS = "1";
                MACHINE_LEARNING_WORKER_TIMEOUT = "120";
                TZ = config.time.timeZone;
                # The image already points its model/HF/JIT caches at `/cache`; this catches anything
                # else that would otherwise try `$HOME/.cache` as a uid with no home directory.
                XDG_CACHE_HOME = "/cache";
              };

              # Re-resolve with:
              #   skopeo inspect --override-os linux --override-arch amd64 docker://ghcr.io/open-noodle/gallery-ml:<tag>
              image = "ghcr.io/open-noodle/gallery-ml:v5.11.0@sha256:0688149a40fb202a71e70e31dda2a4948191d65e4f7a06a42ac0dc9ce421b925";
              volumes = [ "/var/cache/immich:/cache" ];
            };

            immich-server = common // {
              # `services.immich`'s own environment (DB_URL over the Postgres socket, REDIS_SOCKET,
              # IMMICH_MEDIA_LOCATION, IMMICH_CONFIG_FILE, ...) - usable as-is because every path
              # it names is mounted at the same path below. The media location in particular has to
              # stay `/metalminds/pictures` (not the image's `/data`): Immich stores absolute asset
              # paths in its database.
              environment = cfg.environment // {
                TZ = config.time.timeZone;
              };

              extraOptions = common.extraOptions ++ [ "--group-add=${toString config.users.groups.redis-immich.gid}" ];
              # Re-resolve with:
              #   skopeo inspect --override-os linux --override-arch amd64 docker://ghcr.io/open-noodle/gallery-server:<tag>
              image = "ghcr.io/open-noodle/gallery-server:v5.11.0@sha256:82d1710fa48fa57c16f923d074c90350d91d86ac6cf98458908d7a4b2b5c6761";

              volumes = [
                "${cfg.mediaLocation}:${cfg.mediaLocation}"
                "${dirOf cfg.environment.IMMICH_CONFIG_FILE}:${dirOf cfg.environment.IMMICH_CONFIG_FILE}:ro"
                "${cfg.database.host}:${cfg.database.host}"
                "${dirOf cfg.redis.host}:${dirOf cfg.redis.host}"
              ];
            };
          };
        };

      # `settings.terraform = "variable";` (not just any secret) - it now feeds a Terraform
      # `variable` (modules/terranix.nix's two modes) as well as Immich's own `environmentFile`-
      # style secret consumption below, so it's NOT `intermediary` - unlike a secret that ONLY ever
      # feeds a Terraform `variable`, this one is ALSO read directly by `services.immich` below via
      # its own decrypted file, so it has to be materialized as a real host secret.
      secrets.immich-oidc-client-secret = {
        generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
        settings.terraform = "variable";
      };

      virtual-host = {
        inherit global port;
        group = "Media";
        homepage.description = "Photo & video backup";
        host = host.name;
        icon = "immich.svg";
        # Display-only (Homepage tile, Authentik library). `name` - and so the hostname and the
        # Authentik slug/OIDC client id - deliberately stays `immich`: Noodle Gallery speaks
        # Immich's API, so existing Immich mobile apps keep pointing at the same server URL.
        label = "Noodle Gallery";
        # Immich's own recommended reverse-proxy limit (docs.immich.app/administration/reverse-proxy).
        # nginx's 10m default silently 413'd every RAW (.ORF ~20MB), video, and large JPEG on upload.
        maxBodySize = "50000M";
        name = "immich";

        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Per Immich's own OIDC docs
        # (docs.immich.app/administration/oauth) - web login redirects to `/auth/login`, the "link
        # another device" flow redirects to `/user-settings`, and the mobile app comes in through
        # the HTTPS override below (`mobileRedirectUri`) rather than its native
        # `app.immich:///oauth-callback` scheme, which Authentik doesn't need to know about as a
        # result.
        oidc = {
          client-secret = "immich-oidc-client-secret";

          redirect-paths = [
            "/auth/login"
            "/user-settings"
            "/api/oauth/mobile-redirect"
          ];
        };

        # Immich sets its own secure/HttpOnly/SameSite flags on its session cookie. Without this,
        # nginx's blanket cookie rewrite appends a second, duplicate set of those flags, producing
        # a malformed Set-Cookie the browser silently refuses to store — login succeeds
        # server-side but the session never sticks, so the UI hangs forever waiting for one that
        # never arrives.
        preserveCookieFlags = true;
        # Immich's frontend opens a WebSocket right after login for real-time updates (job
        # progress, live sync); without this the connection silently fails and the UI hangs.
        websockets = true;
      };
    };
}
