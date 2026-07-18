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
      virtual-host = {
        name = "prowlarr";
        host = host.name;
        protected = true;
        # Prowlarr serves its own REST API under /api, and proxies per-indexer Torznab requests
        # under /<indexerId>/api; nginx.nix lets both through the Authentik forward-auth gate
        # untouched since cross-seed calls them directly with an API key, machine-to-machine, with
        # no browser session to carry an Authentik cookie.
        bypassAuthPaths = [
          "^/api"
          "^/[0-9]+/api"
        ];
        inherit port global;
        label = "Prowlarr";
        icon = "prowlarr.svg";
        group = "Arr Stack";
        homepage = {
          description = "Indexer manager/proxy";
          widget = {
            type = "prowlarr";
            # Hit Prowlarr directly rather than through nginx/Authentik, since Homepage's
            # server-side widget fetch has no browser session to pass the forward-auth gate.
            url = "http://127.0.0.1:${toString port}";
            api-key = true;
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

      nixos = { config, ... }: {
        services = {
          prowlarr = {
            enable = true;
            settings = {
              server = { inherit port; };
              # Prowlarr only reaches this vhost via nginx over loopback (its port isn't opened in
              # the firewall), so every request it sees is "local" — this drops Prowlarr's own
              # login screen in favor of the Authentik forward-auth gate in front of it, rather
              # than stacking both.
              auth.required = "DisabledForLocalAddresses";
            };
            environmentFiles = [ config.age.secrets."prowlarr.env".path ];
          };
          flaresolverr.enable = true;
        };
      };
    };
}
