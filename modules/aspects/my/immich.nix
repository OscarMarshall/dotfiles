{ lib, inputs, ... }:
let
  port = 2283;
in
{
  # Noodle Gallery's source (see `services.immich.package` below). Tracks upstream's default branch
  # rather than a release tag so Dependabot's daily flake.lock bumps flag new Noodle work - but the
  # lock has to sit on a release commit whose Immich base matches nixpkgs', so a bump PR is a prompt
  # to re-pin by hand (the override's `assert` fails it otherwise), not something to merge as-is.
  flake-file.inputs.noodle-gallery = {
    url = "github:open-noodle/gallery";
    flake = false;
  };

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
          # Immich base (in its release title, e.g. "v5.9.0 (immich 3.3.5)") matches
          # `pkgs.immich.version`, since nixpkgs pins pnpm/esbuild/geodata for that exact release.
          package = pkgs.immich.overrideAttrs (
            finalAttrs: previousAttrs:
            let
              # The fork leaves upstream's version in its package.json files, so this is the
              # locked source's Immich base - the Noodle release number is only in its tag.
              # Read from the input directly, not `finalAttrs.src`: the `assert` gates the whole
              # attrset, so going through `finalAttrs` would make its own attr names recursive.
              immichBase = (lib.importJSON "${inputs.noodle-gallery}/server/package.json").version;
            in
            # Checked (like seerr.nix's/oscar.nix's own overrides) so a mismatch fails evaluation
            # with a "re-pin" message, rather than quietly building the fork against pnpm/esbuild/
            # geodata pins meant for a different Immich release. Trips from either side: a nixpkgs
            # Immich bump, or a Dependabot bump of `noodle-gallery` onto a newer-based `main`.
            assert
              previousAttrs.version == immichBase
              || throw "immich.nix: pkgs.immich is ${previousAttrs.version} but the locked noodle-gallery source is based on Immich ${immichBase} - re-lock it onto the open-noodle/gallery release based on Immich v${previousAttrs.version} (`nix flake lock --override-input noodle-gallery github:open-noodle/gallery/<release tag's commit>`), then update its `version` and pnpmDeps hash.";
            {
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
                hash = "sha256-14kMBmGwp+9cF6SvyU+IUOZUqFarlOW+b+t3WZ4iKvw=";
              };

              # The fork ships a second workflow plugin, `@immich/plugin-gallery` (its space actions:
              # "Add to space", "Add to space album"), which the server loads from
              # `build/plugins/gallery-core` alongside upstream's core plugin. nixpkgs' build and
              # install phases only know about `plugin-core`, so build and install this one too -
              # same dev deps as plugin-core, already built by the main buildPhase.
              postBuild = (previousAttrs.postBuild or "") + ''
                pnpm --filter @immich/plugin-gallery build
              '';

              postInstall = (previousAttrs.postInstall or "") + ''
                mkdir -p "$out/lib/node_modules/immich/build/plugins/gallery-core"
                cp -r packages/plugin-gallery/{dist,manifest.json} "$out/lib/node_modules/immich/build/plugins/gallery-core/"
              '';

              src = inputs.noodle-gallery;
              # The Noodle release `noodle-gallery` is locked to - not derivable from the source
              # (see `immichBase` above), so kept by hand in step with the lock.
              version = "5.11.0";
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
