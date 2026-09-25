let

  # Seerr has no released OIDC support yet (seerr-team/seerr#2715 is still open). Build from
  # michaelhthomas's PR branch until it lands in a release, then drop this override.
  oidcFork = {
    hash = "sha256-6HR1OMqwaDds0B8u6iA/LTcxF9qtuywzhYsdJ0e3Mkw=";
    owner = "michaelhthomas";
    repo = "seerr";
    rev = "aebd4433738ff01a471642210537bb4e1020d1c2";
  };
  port = 5055;
in
{
  my.seerr =
    {
      global ? false,
    }:
    { host, ... }: {
      # Owned by a dedicated `seerr` system user/group (declared below, in `nixos` - Seerr's own
      # NixOS module runs it under `DynamicUser` instead, which has no fixed name/id to chown a
      # dataset to ahead of time, so this aspect overrides that) - zfs.nix's generic `dataset`-quirk
      # consumer creates it if missing and re-chowns it (`chown -R`) on every activation, and `units`
      # orders `seerr.service` after that (same reasoning as radarr.nix's/paperless.nix's own
      # `dataset` fields) - a stable NAME is enough here precisely because the chown re-runs every
      # time rather than depending on a uid that was only ever pinned once.
      dataset = {
        group = "seerr";
        name = "seerr";
        pool = "metalminds";
        units = [ "seerr" ];
        user = "seerr";
      };

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          # Seerr's OIDC settings have no env-var equivalent yet — only settings.json. Merge our
          # provider config into it on every start, preserving whatever else is already there (the
          # app itself owns the rest of the file).
          #
          # Also backfills `main.mediaServerType` when missing - NOT an OIDC concern, but has to
          # live in this same write, for the same first-boot reason. On a truly fresh install (no
          # settings.json yet, e.g. right after wiping Seerr's data for this Plex -> Jellyfin
          # switch), this script is what CREATES the file, before Seerr itself ever reads it - and
          # `server/lib/overseerrMerge.ts`'s `checkOverseerrMerge()` loads it via `raw = true`
          # (server/lib/settings/index.ts's `load()`), which - unlike a normal load - does NOT
          # merge in `Settings`'s own constructor defaults, just `JSON.parse`s exactly what's on
          # disk. A settings.json containing only `{ main: { oidcLogin: true }, oidc: {...} }` (this
          # script's own output, pre-fix) therefore reads back with `main.mediaServerType ===
          # undefined`, and `checkOverseerrMerge`'s own gate (`if (settings.main.mediaServerType)
          # return false`) exists specifically to detect "already configured, skip the Overseerr-
          # merge compatibility path" - `undefined` is falsy, so it wrongly falls through into that
          # path, which does a raw `INSERT INTO migrations (...)` assuming a table that only
          # `runMigrations()` (called LATER, still unreached) would have created. Confirmed live:
          # crash-looped on `SQLITE_ERROR: no such table: migrations` every single boot, immediately
          # after `[Seerr Migration]`'s own "Failed to insert migration records" log line.
          # `MediaServerType.NOT_CONFIGURED` (4 - server/constants/server.ts; PLEX/JELLYFIN/EMBY are
          # 1/2/3, so this only needs to be non-zero/truthy to take the gate's early-return branch)
          # is exactly `Settings`'s own constructor default for this field - this just writes that
          # default explicitly, rather than actually configuring a media server up front. `//`
          # preserves whatever real value Seerr itself later persists here (e.g. `2` for Jellyfin,
          # once `seerr_jellyfin_settings` - this file's own `terranix` field - applies) across
          # every subsequent restart, instead of stomping it back to 4 on every boot.
          configureOidc = pkgs.writeShellApplication {
            name = "seerr-configure-oidc";

            runtimeInputs = [
              pkgs.coreutils
              pkgs.jq
            ];

            text = ''
              settings="$CONFIG_DIRECTORY/settings.json"
              mkdir -p "$(dirname "$settings")"
              existing="{}"
              [ -f "$settings" ] && existing="$(cat "$settings")"
              client_secret="$(cat "$CREDENTIALS_DIRECTORY/oidc-client-secret")"
              jq -n \
                --argjson existing "$existing" \
                --arg secret "$client_secret" \
                '(($existing.oidc.providers // []) | map(select(.slug != "authentik"))) as $others
                | $existing * {
                  main: {
                    mediaServerType: ($existing.main.mediaServerType // 4),
                    oidcLogin: true
                  },
                  oidc: {
                    providers: ($others + [{
                      slug: "authentik",
                      name: "Authentik",
                      issuerUrl: "https://${config.services.authentik.nginx.host}/application/o/seerr/",
                      clientId: "seerr",
                      clientSecret: $secret,
                      scopes: "openid profile email",
                      newUserLogin: true
                    }])
                  }
                }' >"$settings.tmp"
              mv "$settings.tmp" "$settings"
            '';
          };
          package = pkgs.seerr.overrideAttrs (
            old:
            # Pinned so a seerr version bump forces a check of whether upstream has released OIDC
            # support (seerr-team/seerr#2715, still an open, unmerged PR as of 2026-08-24) - if so,
            # drop the oidcFork override above and go back to the stock package.
            assert
              old.version == "3.4.1"
              || throw "seerr.nix: pkgs.seerr is now ${old.version} (was 3.4.1) - re-check whether seerr-team/seerr#2715 (OIDC support) has merged/released; if so, drop the oidcFork override.";
            rec {
              pname = "seerr";

              pnpmDeps = pkgs.fetchPnpmDeps {
                inherit pname src version;
                fetcherVersion = 3;
                hash = "sha256-sraOsE7jPhSpidcV5X6l8xvHkPGUPoNSN2/6UTMymTs=";
                pnpm = pkgs.pnpm_10.override { nodejs-slim = pkgs.nodejs-slim_22; };
              };

              src = pkgs.fetchFromGitHub {
                inherit (oidcFork)
                  hash
                  owner
                  repo
                  rev
                  ;
              };

              version = "unstable-2026-07-31";
            }
          );
        in
        {
          services.seerr = {
            inherit package port;
            enable = true;
            # Points CONFIG_DIRECTORY straight at the mounted dataset (like paperless.nix's
            # `dataDir`/immich.nix's `mediaLocation`) - the module's own `StateDirectory = "seerr"`
            # (unconditional, not affected by this) still creates/chowns an unused `/var/lib/seerr`
            # alongside it; harmless, just not where Seerr actually reads/writes. Seerr's REAL data
            # lives entirely under this dataset now - `/metalminds/seerr`, not `/var/lib/seerr` - so
            # THIS is the path to wipe for a from-scratch reset (e.g. `rm -rf /metalminds/seerr/*`
            # with the service stopped), not the unused StateDirectory.
            configDir = "/metalminds/seerr";
          };

          systemd.services.seerr.serviceConfig = {
            # Overrides the module's own `DynamicUser = true;` - a dynamically-allocated identity
            # has no stable name/id the `dataset` field above could chown its dataset to ahead of
            # time, unlike the fixed `seerr` user/group declared below.
            DynamicUser = lib.mkForce false;
            EnvironmentFile = config.age.secrets."seerr.env".path;
            ExecStartPre = [ (lib.getExe configureOidc) ];
            Group = "seerr";
            LoadCredential = "oidc-client-secret:${config.age.secrets.seerr-oidc-client-secret.path}";
            # The module's own `ProtectSystem = "strict";` only allow-lists paths it manages itself
            # (StateDirectory's `/var/lib/seerr`, RuntimeDirectory, ...) - `configDir` above points
            # elsewhere, so without this, both `configureOidc` and Seerr itself get "Read-only file
            # system" writing there (confirmed live: `seerr-configure-oidc` failing on
            # `/metalminds/seerr/settings.json.tmp`).
            ReadWritePaths = [ "/metalminds/seerr" ];
            User = "seerr";
          };

          users = {
            groups.seerr = { };

            users.seerr = {
              group = "seerr";
              isSystemUser = true;
            };
          };
        };

      secrets = { secrets, ... }: {
        # Seerr mints its own API key at first boot and persists it in settings.json - there's no
        # env var to preset it like Radarr's/Sonarr's `*_AUTH_APIKEY` (see radarr.nix's own
        # `radarr-api-key` comment for that pattern). This fork (unlike stock seerr-team/seerr)
        # DOES honor an `API_KEY` env var though, both to fill a missing key and to override an
        # existing one on every load (server/lib/settings/index.ts's `load()`/`generateApiKey()`,
        # confirmed against `oidcFork.rev`'s tree) - so this pins Seerr's key to one Nix already
        # knows, giving the `seerr` Terraform provider (this file's own `terranix` field, below) a
        # stable credential instead of one that would otherwise only exist after minting it by hand
        # through the UI post-setup.
        seerr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
          settings.terraform = "variable";
        };

        # `settings.terraform = "variable";` feeds a Terraform `variable` (modules/terranix.nix's
        # two modes); also read directly above (LoadCredential) by `configureOidc`, so it's NOT
        # `intermediary` - it has to be materialized as a real host secret too.
        seerr-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          settings.terraform = "variable";
        };

        "seerr.env".generator = {
          dependencies = { inherit (secrets) seerr-api-key; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'API_KEY=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.seerr-api-key.file})"
            '';
        };
      };

      # Managed via terranix (Nix -> Terraform config, see modules/terranix.nix) and the
      # josh-archer/seerr provider - same class of setup as jellyfin.nix's own `terranix` field,
      # which contributes the `jellyfin_library` resources referenced below. Deliberately doesn't
      # declare `seerr_radarr_server`/`seerr_sonarr_server`/notification-agent resources: those
      # weren't Terraform-managed before this switch either (Seerr's whole config was hand-set
      # through its UI) - reconnecting them post-wipe is the same one-time manual step it always was,
      # just against Jellyfin's Movies/Requests tabs instead of Plex's.
      #
      # One-time bootstrap, required even with a wiped/fresh `/metalminds/seerr` (`dataset` above):
      # `X-Api-Key` auth (server/middleware/auth.ts) only ever authenticates as user ID 1, "the
      # original administrator account" - which doesn't exist until SOME real login creates it, and
      # this provider only knows how to bootstrap that via a Plex admin token (`plex_token`, its own
      # provider-config field), which doesn't apply here. Confirmed live: every `seerr_*` resource
      # 403'd ("You do not have permission to access this endpoint") until this was done by hand.
      # So: open Seerr's own setup wizard once, sign in with a Jellyfin ADMIN account (creates user
      # #1) - the wizard's own Jellyfin-connection/library-selection steps necessarily configure the
      # exact same state as `seerr_jellyfin_settings`/`seerr_jellyfin_library_settings`/
      # `seerr_main_settings` below, so import them into state afterward (one-time, via
      # `nix develop .#<host>-tf`, same as radarr.nix's own equivalent note) rather than letting
      # `tofu apply` try to CREATE resources that already exist:
      #
      #   tofu import seerr_main_settings.main main
      #   tofu import seerr_jellyfin_settings.default jellyfin
      #   tofu import seerr_jellyfin_library_settings.default jellyfin_library_settings
      terranix = { host, ... }: {
        # Inputs to `seerr_user_permissions.authentik-admin` below. `data.authentik_group.admin` reads
        # authentik.nix's own `authentik_group.admin` back as a data source purely to get its
        # MEMBERSHIP (`users_obj`) - that resource deliberately leaves `users` unmanaged (see its own
        # comment), so it's only ever known live, never in this config. `main-settings` is Seerr's
        # own `defaultPermissions`, which neither `seerr_main_settings` resource nor data source
        # exposes, so it's read via the provider's raw-request escape hatch instead.
        data = {
          authentik_group.admin.name = "\${authentik_group.admin.name}";

          seerr_api_request.main-settings = {
            method = "GET";
            path = "/api/v1/settings/main";
          };

          seerr_users.all = { };
        };

        # Lowercased on both sides because Seerr lowercases the email when it creates an OIDC user
        # (server/routes/auth.ts), while Authentik stores whatever case was entered. Inactive
        # Authentik accounts are excluded so deactivating someone also demotes them here.
        locals.seerr-admin-emails = "\${ [ for user in data.authentik_group.admin.users_obj : lower(user.email) if user.is_active && user.email != \"\" ] }";

        provider.seerr = {
          api_key = "\${var.SEERR_API_KEY}";
          url = "https://seerr.${host.name}.${host.domain}";
        };

        resource = {
          # `item_id` (Jellyfin's own internal library GUID), not `id` (the Terraform resource
          # identifier) - Seerr matches libraries by the ID Jellyfin's own API reports, which is
          # `jellyfin_library`'s `item_id` (jellyfin.nix's own resource, cross-referenced here since
          # every aspect's `terranix` field on a host merges into the same Terraform config/state -
          # same pattern nextcloud.nix uses for mailgun.nix's `mailgun_domain.default`).
          seerr_jellyfin_library_settings.default.enabled_libraries = [
            "\${jellyfin_library.movies.item_id}"
            "\${jellyfin_library.tv-shows.item_id}"
          ];

          # `ip`/`port` are jellyfin.nix's own loopback/8096 (`seerr` and Jellyfin both run
          # natively on the same host - see that file's own comments on this same loopback
          # convention). `api_key` is Jellyfin's OWN API key (jellyfin.nix's `jellyfin-api-key`,
          # flipped to `settings.terraform = "variable"` there so it can be read as a plain
          # resource attribute here, not just via the `jellyfin` provider's own implicit env pickup)
          # - a DIFFERENT credential than this file's own `SEERR_API_KEY` above, which authenticates
          # the other direction (Terraform -> Seerr, not Seerr -> Jellyfin). No `name` - despite the
          # provider's own README example setting it, the actual schema marks it read-only (Seerr
          # derives it from the connected server itself) - confirmed live: `tofu apply` refused with
          # "Invalid Configuration for Read-Only Attribute" on it.
          seerr_jellyfin_settings.default = {
            api_key = "\${var.JELLYFIN_API_KEY}";
            external_hostname = "https://jellyfin.${host.name}.${host.domain}";
            ip = "127.0.0.1";
            port = 8096;
            use_ssl = false;
          };

          seerr_main_settings.main = {
            app_title = "Seerr";
            application_url = "https://seerr.${host.name}.${host.domain}";
            locale = "en";
          };

          # Seerr's OIDC login (`oidcFork`) has no group/role claim mapping at all - new users just
          # get `defaultPermissions`, and `requiredClaims` can only gate login, never grant anything
          # (still true at seerr-team/seerr#2715's head as of 2026-09-25). So the Authentik `admin`
          # group -> Seerr ADMIN mapping jellyfin.nix (`AdminRoles`) and nextcloud.nix (group
          # provisioning) get natively is done here instead, matching Seerr users to group members
          # by email.
          #
          # Seerr users only exist after their first login, so a new admin gets promoted on the
          # NEXT `tofu apply` after they first sign in, not instantly.
          #
          # Demotion needs its own entries, because this resource's Delete is a no-op (the provider
          # has no DELETE route to call - it only forgets state), so dropping someone from the group
          # can't just drop them from `for_each`. Instead, any user still holding the ADMIN bit (2,
          # server/lib/permissions.ts - `floor(p / 2) % 2` since Terraform has no bitwise ops) who
          # ISN'T in the group gets reset to `defaultPermissions`; on the apply after that they no
          # longer match and fall out of `for_each` (a harmless state-only "destroy"). Everyone
          # else's permissions are left alone, so per-user tweaks for non-admins still work through
          # Seerr's UI. User 1 is excluded: it's the owner account (created by the bootstrap
          # sign-in, see above), always admin, and Seerr refuses edits to it from anyone but itself.
          seerr_user_permissions.authentik-admin = {
            for_each = "\${ { for user in data.seerr_users.all.users : user.id => contains(local.seerr-admin-emails, lower(coalesce(user.email, \"-\"))) if user.id != \"1\" && (contains(local.seerr-admin-emails, lower(coalesce(user.email, \"-\"))) || floor(user.permissions / 2) % 2 == 1) } }";
            permissions = "\${each.value ? 2 : jsondecode(data.seerr_api_request.main-settings.response_body_json).defaultPermissions}";
            user_id = "\${tonumber(each.key)}";
          };
        };

        terraform.required_providers.seerr.source = "josh-archer/seerr";
        variable.SEERR_API_KEY.sensitive = true;
      };

      virtual-host = {
        inherit global port;
        group = "Media";
        homepage.description = "Media requests";
        host = host.name;
        icon = "seerr.svg";
        label = "Seerr";
        name = "seerr";

        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Redirect paths per the OIDC setup docs for
        # this exact fork revision (docs/using-seerr/settings/users/oidc.md at `oidcFork.rev`
        # above).
        oidc = {
          client-secret = "seerr-oidc-client-secret";

          redirect-paths = [
            "/login"
            "/profile/settings/linked-accounts"
          ];
        };
      };
    };
}
