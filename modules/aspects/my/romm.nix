{ lib, ... }: {
  my.romm =
    {
      administrators ? [ ],
      global ? false,
    }:
    { host, ... }:
    let
      dataDir = "/metalminds/romm";

      # Like storyteller.nix's own `url`, `global` SWITCHES the served hostname rather than adding an
      # alias next to it. RomM takes exactly one `OIDC_REDIRECT_URI` (below), and its OIDC state
      # lives in a session cookie scoped to whichever host started the login - so a login begun on
      # the other name would come back to this one without that cookie and fail the state check.
      # One name has to be canonical.
      url = if global then "romm.${host.domain}" else "romm.${host.name}.${host.domain}";
    in
    {
      # One dataset for everything RomM keeps - the ROM library itself (`library/`, a path upstream
      # fixes under `services.romm.dataDir`) next to its own state (`assets/` holds uploaded saves
      # and save states, `config/`, `resources/` for fetched artwork, and the auth secret the module
      # generates on first start). Shared over Samba so ROMs can be dropped straight into `library/`
      # - see the tmpfiles override below for why that needs group write.
      dataset = {
        # RomM's Postgres DB (database.createLocally, default "romm") lives outside the dataset, so
        # dump it in before each backup - same shape as paperless.nix's/immich.nix's. `library/`
        # and `cache/` are excluded: ROMs are bulky and re-obtainable, and `cache/` is just
        # regenerated download archives - everything irreplaceable (saves, states, the DB) still
        # goes offsite.
        backup = pkgs: {
          backupCleanupCommand = "rm -f ${dataDir}/.backup/db.sql";

          backupPrepareCommand = ''
            umask 077
            mkdir -p ${dataDir}/.backup
            ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump romm > ${dataDir}/.backup/db.sql
          '';

          exclude = [
            "${dataDir}/cache"
            "${dataDir}/library"
          ];
        };

        group = "romm";
        name = "romm";
        pool = "metalminds";
        samba = true;

        units = [
          "romm"
          "romm-scheduler"
          "romm-watcher"
          "romm-worker"
        ];

        user = "romm";
      };

      nixos = { config, ... }: {
        services.romm = {
          inherit dataDir;
          enable = true;
          environmentFile = config.age.secrets."romm.env".path;

          extraEnvironment = {
            # Authentik is the only way in, same as immich.nix: no local password form, no
            # first-run wizard (whose only job is creating a local admin), and the login page
            # bounces straight to Authentik. Roles come from the `groups` claim Authentik's default
            # `profile` scope already emits (see authentik.nix's `oidc-defaults`) - its `admin`
            # group becomes a RomM admin, `user` a regular account. Authentik's own application
            # bindings already keep everyone else out before RomM ever sees them.
            DISABLE_SETUP_WIZARD = "true";
            DISABLE_USERPASS_LOGIN = "true";
            # Metadata sources that need no account. IGDB/ScreenScraper/SteamGridDB/RetroAchievements
            # all need personal credentials - add them to `romm.env` below if wanted.
            ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA = "true";
            HASHEOUS_API_ENABLED = "true";
            HLTB_API_ENABLED = "true";
            LAUNCHBOX_API_ENABLED = "true";
            OIDC_AUTOLOGIN = "true";
            OIDC_CLAIM_ROLES = "groups";
            OIDC_CLIENT_ID = "romm";
            OIDC_ENABLED = "true";
            OIDC_PROVIDER = "Authentik";
            OIDC_REDIRECT_URI = "https://${url}/api/oauth/openid";
            OIDC_ROLE_ADMIN = "admin";
            OIDC_ROLE_VIEWER = "user";
            OIDC_SERVER_APPLICATION_URL = "https://${config.services.authentik.nginx.host}/application/o/romm/";
            PLAYMATCH_API_ENABLED = "true";
          };

          # Served under nginx.nix's own vhost for `url`: the module fills in its root/locations
          # (frontend, API proxy, X-Accel ROM downloads), nginx.nix adds TLS - same split as
          # nextcloud.nix. Also what the module derives ROMM_BASE_URL and the secure session
          # cookie from.
          nginx.virtualHost = url;
        };

        # The module's `/` location sets its own `add_header`s (cache control, the emulator's
        # cross-origin isolation), and nginx then drops every inherited one there - nginx.nix's
        # site-wide security headers included (the build's gixy check refuses that). Restored
        # here, but with `SAMEORIGIN` rather than nginx.nix's `DENY`: RomM frames its own pages
        # (the EasyRPG player, the text viewer).
        services.nginx.virtualHosts.${url}.locations."/".extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          add_header Referrer-Policy origin-when-cross-origin;
          add_header X-Frame-Options SAMEORIGIN;
          add_header X-Content-Type-Options nosniff;
        '';

        # The module's tmpfiles rules run at boot before the pool is imported, so on a fresh
        # dataset its subdirectories don't exist yet - and the watcher fails outright without
        # `library/`. Recreate them as RomM itself, after zfs.nix has created and chowned the
        # dataset (`units` above).
        systemd = {
          services.romm.preStart = lib.mkBefore ''
            mkdir -p ${dataDir}/{assets,cache,config,library,resources}
          '';

          # The module pins `library/` to 0750, which leaves Samba writers (administrators, via the
          # `romm` group below) read-only - zfs.nix's own `chmod g+rwX` would be undone by tmpfiles
          # on the next activation.
          tmpfiles.settings."10-romm"."${dataDir}/library".d.mode = lib.mkForce "0770";
        };

        users.users = lib.genAttrs administrators (user: {
          extraGroups = [ "romm" ];
        });
      };

      secrets = { secrets, ... }: {
        # `intermediary` like storyteller.nix's: the host only ever reads it through `romm.env`
        # below; on its own it just feeds Authentik's side via a Terraform `variable`.
        romm-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = "variable";
        };

        "romm.env".generator = {
          dependencies = { inherit (secrets) romm-oidc-client-secret; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'OIDC_CLIENT_SECRET=%s\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.romm-oidc-client-secret.file}
              )"
            '';
        };
      };

      virtual-host = {
        inherit global url;
        group = "Media";
        homepage.description = "Retro game library & in-browser emulation";
        host = host.name;
        icon = "romm.svg";
        label = "RomM";
        name = "romm";

        # Native OIDC (no `protected`) - forward-auth on top would mean logging in twice and would
        # break RomM's companion apps, which hold API tokens rather than a browser session.
        # `email-verified`: RomM refuses any login whose `email_verified` claim is false, which
        # Authentik's stock email mapping always sends - see authentik.nix.
        oidc = {
          client-secret = "romm-oidc-client-secret";
          email-verified = true;
          redirect-paths = [ "/api/oauth/openid" ];
        };

        # RomM sets its own Secure/SameSite=Lax session cookie. nginx.nix's blanket rewrite would
        # append SameSite=strict on top, and a strict cookie isn't sent on the cross-site redirect
        # back from Authentik - losing the OIDC state and failing every login.
        preserveCookieFlags = true;
      };
    };
}
