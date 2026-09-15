{ lib, ... }: {
  my.sonarr =
    {
      administrators,
      global ? false,
    }:
    { host, ... }:
    let
      # Matches virtual-host.nix's own derived hostname (`${name}.${host.name}.<domain>`) - no
      # shared domain constant exists in this repo (authentik.nix/dns.nix/nginx.nix each carry this
      # same literal), so this matches that convention rather than introducing one.
      domain = "silverlight-nex.us";
      port = 8989;
    in
    {
      # Owned by Sonarr's own native NixOS service user/group (`sonarr`, confirmed via
      # `config.services.sonarr.user`/`.group`) - zfs.nix's generic `dataset`-quirk consumer chowns
      # it once created, and `units` orders the `sonarr.service` unit after that (avoids it starting
      # before this exists/is mounted - see zfs.nix's own comment on why that's a real risk).
      dataset = {
        group = "sonarr";
        guestAccess = true;
        name = "shows";
        pool = "metalminds";
        samba = true;
        units = [ "sonarr" ];
        user = "sonarr";
      };

      nixos = { config, ... }: {
        services.sonarr = {
          enable = true;
          environmentFiles = [ config.age.secrets."sonarr.env".path ];

          # Sonarr only reaches this vhost via nginx (its port isn't opened in the firewall), and
          # every such request already passed the Authentik forward-auth gate in front of it - so
          # Sonarr's own login is pure redundancy. `auth.required = "DisabledForLocalAddresses"`
          # used to paper over that by treating loopback-proxied requests as local, but ASP.NET
          # Core's forwarded-headers middleware rewrites the remote address from nginx's
          # X-Forwarded-For header before that check runs, so "local" actually tracked the real
          # client's address - true from the LAN, false the moment access came from anywhere else,
          # which is why the login started reappearing. `auth.method = "External"` (unlisted in
          # Sonarr's own UI, but a real, supported value) sidesteps the IP heuristic entirely:
          # Sonarr treats every request as already authenticated, full stop, leaving Authentik as
          # the sole real gate - matching what this was always supposed to do. `required` is
          # pinned to "Enabled" alongside it (rather than left unset) so nothing falls back to
          # Sonarr's own persisted config.xml value, which could still be the old
          # "DisabledForLocalAddresses" - it's moot once `method` already authenticates every
          # request, but keeps that heuristic from silently reappearing if it ever weren't.
          settings.auth = {
            method = "External";
            required = "Enabled";
          };
        };

        users.users = {
          sonarr.extraGroups = [ "qbittorrent" ];
        }
        // (lib.genAttrs administrators (user: {
          extraGroups = [ "sonarr" ];
        }));
      };

      secrets = { secrets, ... }: {
        sonarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;

          settings = {
            homepage = "sonarr";
            terraform = "variable";
          };
        };

        "sonarr.env".generator = {
          dependencies = { inherit (secrets) sonarr-api-key; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'SONARR__AUTH__APIKEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.sonarr-api-key.file})"
            '';
        };
      };

      # Root folder, managed via terranix (Nix -> Terraform config, see modules/terranix.nix) and
      # the devopsarr/sonarr provider - see radarr.nix's `terranix` field for why `sonarr-api-key`
      # is flagged `settings.terraform = "variable";` rather than relying on implicit env-var
      # pickup (Prowlarr's `prowlarr_application_sonarr` needs the same key as a plain resource
      # attribute).
      #
      # The qBittorrent download client below is built from the `torrent-client` quirk
      # (torrent-client.nix) - qbittorrent.nix is the one place that knows its real connection
      # details; this aspect just picks the entry and formats it into the
      # `sonarr_download_client_qbittorrent` shape (`tv_category` is Sonarr's own field name for
      # this - see radarr.nix's/bookshelf.nix's own `terranix` fields for their equivalents).
      #
      # `sonarr_media_management` leaves `hardlinks_copy` on (Sonarr's own default) - see radarr.nix's
      # own comment on its identical `radarr_media_management` resource for why that's fine despite
      # `shows`/`torrents` being separate ZFS datasets (hardlink attempts across them transparently
      # fall back to a copy; the delete-of-the-original that follows is what actually needed fixing,
      # solved centrally in zfs.nix's `dataset` quirk). Every field below has been reconciled against
      # this instance's own actual live settings (via `tofu plan` after importing), then further
      # aligned with radarr.nix's/bookshelf.nix's identical resources on a couple of fields that had
      # drifted across the three apps for no real reason - see the resource's own comment, right
      # above it, for which fields and why.
      #
      # These resources already exist by hand in the running instance; applying without importing
      # first would create duplicates (same situation `authentik_outpost.embedded` was in - see
      # authentik.nix's comment on that resource). One-time, via `nix develop .#<host>-tf`
      # (AUTHENTIK_TOKEN-style env sourcing is automatic, see modules/terranix.nix's `prefixText`):
      #
      #   tofu import sonarr_root_folder.shows <id>                     # GET /api/v3/rootfolder
      #   tofu import sonarr_download_client_qbittorrent.qbittorrent <id> # GET /api/v3/downloadclient
      #   tofu import sonarr_media_management.default ""                # GET /api/v3/config/mediamanagement
      terranix =
        {
          lib,
          host,
          torrent-client,
          ...
        }:
        let
          qbittorrent = lib.findFirst (
            tc: tc.kind == "qbittorrent"
          ) (throw "sonarr.nix: no qbittorrent torrent-client entry found") torrent-client;
        in
        {
          provider.sonarr = {
            api_key = "\${var.SONARR_API_KEY}";
            url = "https://sonarr.${host.name}.${domain}";
          };

          resource = {
            sonarr_download_client_qbittorrent.qbittorrent = {
              inherit (qbittorrent) host;
              inherit (qbittorrent) port;
              enable = true;
              name = "qBittorrent";
              priority = 1;
              tv_category = "sonarr";
              tv_imported_category = "sonarr-imported";
            };

            # Reconciled against the actual live values (`tofu plan` after importing), then aligned
            # with radarr.nix's/bookshelf.nix's own identical resources on `import_extra_files`/
            # `extra_file_extensions` (matching Radarr's own prior value, extended here and in
            # bookshelf.nix) - the three apps had drifted (each configured by hand at a different
            # time) and there was no reason for Sonarr specifically to differ; everything else
            # (including `hardlinks_copy`, left at Sonarr's own default - see this resource's own
            # header comment for why that's fine here) already matched Sonarr's real settings.
            sonarr_media_management.default = {
              chmod_folder = "775";
              chown_group = "";
              create_empty_folders = true;
              delete_empty_folders = true;
              download_propers_repacks = "preferAndUpgrade";
              enable_media_info = true;
              episode_title_required = "always";
              extra_file_extensions = "srt,ass";
              file_date = "none";
              hardlinks_copy = true;
              import_extra_files = true;
              minimum_free_space = 100;
              recycle_bin_days = 7;
              recycle_bin_path = "";
              rescan_after_refresh = "always";
              set_permissions = true;
              skip_free_space_check = false;
              unmonitor_previous_episodes = false;
            };

            sonarr_root_folder.shows.path = "/metalminds/shows";
          };

          terraform.required_providers.sonarr.source = "devopsarr/sonarr";
          variable.SONARR_API_KEY.sensitive = true;
        };

      virtual-host = {
        inherit global port;
        # Sonarr serves its REST API under /api; nginx.nix lets that through the Authentik
        # forward-auth gate untouched since cross-seed/unpackerr call it directly with an API key,
        # machine-to-machine, with no browser session to carry an Authentik cookie.
        bypassAuthPaths = [ "^/api" ];
        group = "Arr Stack";

        homepage = {
          description = "Show organizer/manager";

          widget = {
            api-key = true;
            enableQueue = true;
            type = "sonarr";
            # Hit Sonarr directly rather than through nginx/Authentik, since Homepage's
            # server-side widget fetch has no browser session to pass the forward-auth gate.
            url = "http://127.0.0.1:${toString port}";
          };
        };

        host = host.name;
        icon = "sonarr.svg";
        label = "Sonarr";
        name = "sonarr";
        protected = true;
        # Sonarr's UI keeps a SignalR (WebSocket) connection open for live queue/activity updates -
        # without this, nginx's recommendedProxySettings clears the Connection header
        # (see nginx.nix's `proxyWebsockets` comment) and the upgrade is refused.
        websockets = true;
      };
    };
}
