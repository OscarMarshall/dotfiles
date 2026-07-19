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
              # Prowlarr only reaches this vhost via nginx over loopback (its port isn't opened in
              # the firewall), so every request it sees is "local" — this drops Prowlarr's own
              # login screen in favor of the Authentik forward-auth gate in front of it, rather
              # than stacking both.
              auth.required = "DisabledForLocalAddresses";
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
              decrypt,
              deps,
              lib,
              ...
            }:
            ''
              printf 'PROWLARR__AUTH__APIKEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file})"
            '';
        };
      };
      virtual-host = {
        inherit port global;
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
