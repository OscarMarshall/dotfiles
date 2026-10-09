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
      # Owned by Immich's own native NixOS service user/group (`immich`, confirmed via
      # `config.services.immich.user`/`.group`) - zfs.nix's generic `dataset`-quirk consumer chowns
      # it once created, and `units` orders both immich-server and immich-machine-learning after
      # that (avoids either starting before this exists/is mounted - see zfs.nix's own comment on
      # why that's a real risk).
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
          "immich-machine-learning"
          "immich-server"
        ];

        user = "immich";
      };

      nixos = { config, pkgs, ... }: {
        services.immich = {
          inherit port;
          enable = true;

          # Noodle Gallery (github.com/open-noodle/gallery) rather than upstream Immich - a soft fork
          # (adds family/partner sharing and shared face recognition) that its own docs pitch as a
          # drop-in: same database schema, same media layout, same config file, same mobile/OAuth
          # endpoints. So rather than switching to its Docker images, this keeps NixOS's own
          # `services.immich` (Postgres + VectorChord, Redis, users, hardening, the backup hook
          # above) and only swaps the source tree under nixpkgs' own `immich` derivation. The fork
          # keeps upstream's pnpm workspace names (`immich`, `immich-web`, `@immich/plugin-core`),
          # so nixpkgs' build/install phases apply unchanged - but only while each Noodle release's
          # Immich base (in its release title, e.g. "v5.7.1 (immich v3.2.4)") matches
          # `pkgs.immich.version`, since nixpkgs pins pnpm/esbuild/geodata for that exact release.
          # Bump `version` here alongside every nixpkgs Immich bump.
          package = pkgs.immich.overrideAttrs (
            finalAttrs: previousAttrs: {
              # The module runs `cfg.package.machine-learning`, built by nixpkgs from
              # `"${src}/machine-learning"` - so it picks up the fork's source on its own, but the
              # fork's ML adds one dependency upstream doesn't have (`prometheus-client`, for its
              # metrics endpoint). Adding it to `dependencies` alone only satisfies the build's
              # runtime-deps check: nixpkgs' `machine-learning` wrapper bakes its PYTHONPATH from
              # the ORIGINAL `dependencies` list (a `rec` binding in its package.nix, which
              # `overridePythonAttrs` can't reach), so the wrapper needs the extra path too or the
              # service would fail importing it at startup.
              passthru = previousAttrs.passthru // {
                machine-learning =
                  (pkgs.immich-machine-learning.override { immich = finalAttrs.finalPackage; }).overridePythonAttrs
                    (previousMlAttrs: {
                      dependencies = previousMlAttrs.dependencies ++ [ pkgs.python3.pkgs.prometheus-client ];

                      # Broken upstream in v5.7.1, not by anything Nix-specific: the fork's
                      # `PetRecognizer._predict` now skips crops under `_MIN_CROP_SIDE`, but these
                      # tests still mock exactly one embedding per (tiny, e.g. 10x10) box, so its
                      # `zip(..., strict=True)` trips on the count mismatch. Drop once fixed upstream.
                      disabledTests = (previousMlAttrs.disabledTests or [ ]) ++ [
                        "test_recognizer_crops_each_bounding_box"
                        "test_recognizer_raises_on_embedding_count_mismatch"
                        "test_recognizer_returns_one_embedding_per_pet"
                        "test_recognizer_uses_area_interpolation_downscaling_and_linear_upscaling"
                      ];

                      postInstall = previousMlAttrs.postInstall + ''
                        wrapProgram "''${!outputBin}"/bin/machine-learning \
                          --prefix PYTHONPATH : ${pkgs.python3.pkgs.makePythonPath [ pkgs.python3.pkgs.prometheus-client ]}
                      '';
                    });
              };

              pname = "noodle-gallery";

              # Same call as nixpkgs' own (fetcherVersion included) - only the lockfile differs.
              pnpmDeps = pkgs.fetchPnpmDeps {
                inherit (finalAttrs) pname src version;
                inherit (previousAttrs.passthru) pnpm;
                fetcherVersion = 4;
                hash = "sha256-HgBSKC0dfmyH9xXIJv6Z7ZFJy4MSTNfPCfQJ8a6djSQ=";
              };

              src = pkgs.fetchFromGitHub {
                hash = "sha256-1Gm/hTL6Szm2wFm2gJHxUOPQ/rFsuaDxaMvl7KbR23M=";
                owner = "open-noodle";
                repo = "gallery";
                tag = "v${finalAttrs.version}";
              };

              version = "5.7.1";
            }
          );

          host = "127.0.0.1";
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

        users.users = lib.genAttrs administrators (user: {
          extraGroups = [ "immich" ];
        });
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
