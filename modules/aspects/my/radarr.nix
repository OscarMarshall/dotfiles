{ lib, ... }:
let
  # Matches virtual-host.nix's own derived hostname (`${name}.${host.name}.<domain>`) - no shared
  # domain constant exists in this repo (authentik.nix/dns.nix/nginx.nix each carry this same
  # literal), so this matches that convention rather than introducing one.
  domain = "silverlight-nex.us";
  port = 7878;
in
{
  my.radarr =
    {
      administrators,
      global ? false,
    }:
    { host, ... }: {
      nixos = { config, ... }: {
        services.radarr = {
          enable = true;
          environmentFiles = [ config.age.secrets."radarr.env".path ];

          # Radarr only reaches this vhost via nginx (its port isn't opened in the firewall), and
          # every such request already passed the Authentik forward-auth gate in front of it - so
          # Radarr's own login is pure redundancy. `auth.required = "DisabledForLocalAddresses"`
          # used to paper over that by treating loopback-proxied requests as local, but ASP.NET
          # Core's forwarded-headers middleware rewrites the remote address from nginx's
          # X-Forwarded-For header before that check runs, so "local" actually tracked the real
          # client's address - true from the LAN, false the moment access came from anywhere else,
          # which is why the login started reappearing. `auth.method = "External"` (unlisted in
          # Radarr's own UI, but a real, supported value) sidesteps the IP heuristic entirely:
          # Radarr treats every request as already authenticated, full stop, leaving Authentik as
          # the sole real gate - matching what this was always supposed to do. `required` is
          # pinned to "Enabled" alongside it (rather than left unset) so nothing falls back to
          # Radarr's own persisted config.xml value, which could still be the old
          # "DisabledForLocalAddresses" - it's moot once `method` already authenticates every
          # request, but keeps that heuristic from silently reappearing if it ever weren't.
          settings.auth = {
            method = "External";
            required = "Enabled";
          };
        };

        users.users = {
          radarr.extraGroups = [ "qbittorrent" ];
        }
        // (lib.genAttrs administrators (user: {
          extraGroups = [ "radarr" ];
        }));
      };

      secrets = { secrets, ... }: {
        radarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;

          settings = {
            homepage = "radarr";
            terraform = "variable";
          };
        };

        "radarr.env".generator = {
          dependencies = { inherit (secrets) radarr-api-key; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'RADARR__AUTH__APIKEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.radarr-api-key.file})"
            '';
        };
      };

      # Root folder, managed via terranix (Nix -> Terraform config, see modules/terranix.nix) and
      # the devopsarr/radarr provider - same pattern as authentik.nix. `radarr-api-key` below is
      # flagged `settings.terraform = "variable";` (not `= true;`) rather than relying on the
      # provider's implicit RADARR_API_KEY env-var pickup, because the SAME key also has to appear
      # as a plain RESOURCE ATTRIBUTE value in prowlarr.nix's `prowlarr_application_radarr`
      # (Prowlarr needs Radarr's own API key as data to sync indexers to it, not just as Radarr's
      # provider auth) - a `variable` is the only mode one secret can be read in from two different
      # places in the generated config.
      #
      # The download-client connection to qBittorrent is declared via the `torrent-client` quirk
      # below instead of directly here - see torrent-client.nix for why that's owned by
      # qbittorrent.nix rather than duplicated across every *arr aspect.
      #
      # This resource already exists by hand in the running instance; applying without importing
      # first would create a duplicate (same situation `authentik_outpost.embedded` was in - see
      # authentik.nix's comment on that resource). One-time, via `nix develop .#<host>-tf`
      # (AUTHENTIK_TOKEN-style env sourcing is automatic, see modules/terranix.nix's `prefixText`):
      #
      #   tofu import radarr_root_folder.movies <id>  # GET /api/v3/rootfolder
      terranix = { host, ... }: {
        provider.radarr = {
          api_key = "\${var.RADARR_API_KEY}";
          url = "https://radarr.${host.name}.${domain}";
        };

        resource.radarr_root_folder.movies.path = "/metalminds/movies";

        terraform.required_providers.radarr = {
          source = "devopsarr/radarr";
          version = "~> 2.4";
        };

        variable.RADARR_API_KEY.sensitive = true;
      };

      torrent-client = {
        kind = "radarr";
        name = "radarr";
      };

      virtual-host = {
        inherit global port;
        # Radarr serves its REST API under /api; nginx.nix lets that through the Authentik
        # forward-auth gate untouched since cross-seed/unpackerr call it directly with an API key,
        # machine-to-machine, with no browser session to carry an Authentik cookie.
        bypassAuthPaths = [ "^/api" ];
        group = "Arr Stack";

        homepage = {
          description = "Movie organizer/manager";

          widget = {
            api-key = true;
            enableQueue = true;
            type = "radarr";
            # Hit Radarr directly rather than through nginx/Authentik, since Homepage's
            # server-side widget fetch has no browser session to pass the forward-auth gate.
            url = "http://127.0.0.1:${toString port}";
          };
        };

        host = host.name;
        icon = "radarr.svg";
        label = "Radarr";
        name = "radarr";
        protected = true;
      };
    };
}
