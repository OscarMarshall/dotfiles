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
      # These resources already exist by hand in the running instance; applying without importing
      # first would create duplicates (same situation `authentik_outpost.embedded` was in - see
      # authentik.nix's comment on that resource). One-time, via `nix develop .#<host>-tf`
      # (AUTHENTIK_TOKEN-style env sourcing is automatic, see modules/terranix.nix's `prefixText`):
      #
      #   tofu import sonarr_root_folder.shows <id>                     # GET /api/v3/rootfolder
      #   tofu import sonarr_download_client_qbittorrent.qbittorrent <id> # GET /api/v3/downloadclient
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
            };

            sonarr_root_folder.shows.path = "/metalminds/shows";
          };

          terraform.required_providers.sonarr = {
            source = "devopsarr/sonarr";
            version = "~> 3.4";
          };

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
