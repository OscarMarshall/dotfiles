{
  my.prowlarr =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 9696;
    in
    {
      nixos = { config, ... }: {
        services = {
          flaresolverr.enable = true;

          prowlarr = {
            enable = true;
            environmentFiles = [ config.age.secrets."prowlarr.env".path ];

            settings = {
              # Prowlarr only reaches this vhost via nginx (its port isn't opened in the
              # firewall), and every such request already passed the Authentik forward-auth gate
              # in front of it - so Prowlarr's own login is pure redundancy.
              # `auth.required = "DisabledForLocalAddresses"` used to paper over that by treating
              # loopback-proxied requests as local, but ASP.NET Core's forwarded-headers
              # middleware rewrites the remote address from nginx's X-Forwarded-For header before
              # that check runs, so "local" actually tracked the real client's address - true from
              # the LAN, false the moment access came from anywhere else, which is why the login
              # started reappearing. `auth.method = "External"` (unlisted in Prowlarr's own UI,
              # but a real, supported value) sidesteps the IP heuristic entirely: Prowlarr treats
              # every request as already authenticated, full stop, leaving Authentik as the sole
              # real gate - matching what this was always supposed to do. `required` is pinned to
              # "Enabled" alongside it (rather than left unset) so nothing falls back to
              # Prowlarr's own persisted config.xml value, which could still be the old
              # "DisabledForLocalAddresses" - it's moot once `method` already authenticates every
              # request, but keeps that heuristic from silently reappearing if it ever weren't.
              auth = {
                method = "External";
                required = "Enabled";
              };

              server = { inherit port; };
            };
          };
        };
      };

      secrets = { secrets, ... }: {
        prowlarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
          settings.homepage = "prowlarr";
        };

        "prowlarr.env".generator = {
          dependencies = { inherit (secrets) prowlarr-api-key; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'PROWLARR__AUTH__APIKEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file})"
            '';
        };
      };

      virtual-host = {
        inherit global port;

        # Prowlarr serves its own REST API under /api, and proxies per-indexer Torznab requests
        # under /<indexerId>/api; nginx.nix lets both through the Authentik forward-auth gate
        # untouched since cross-seed calls them directly with an API key, machine-to-machine, with
        # no browser session to carry an Authentik cookie.
        bypassAuthPaths = [
          "^/api"
          "^/[0-9]+/api"
        ];

        group = "Arr Stack";

        homepage = {
          description = "Indexer manager/proxy";

          widget = {
            api-key = true;
            type = "prowlarr";
            # Hit Prowlarr directly rather than through nginx/Authentik, since Homepage's
            # server-side widget fetch has no browser session to pass the forward-auth gate.
            url = "http://127.0.0.1:${toString port}";
          };
        };

        host = host.name;
        icon = "prowlarr.svg";
        label = "Prowlarr";
        name = "prowlarr";
        protected = true;
      };
    };
}
