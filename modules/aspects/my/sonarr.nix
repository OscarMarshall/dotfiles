{ lib, ... }: {
  my.sonarr =
    {
      administrators,
      global ? false,
    }:
    { host, ... }:
    let
      port = 8989;
    in
    {
      virtual-host = {
        name = "sonarr";
        host = host.name;
        protected = true;
        # Sonarr serves its REST API under /api; nginx.nix lets that through the Authentik
        # forward-auth gate untouched since cross-seed/unpackerr call it directly with an API key,
        # machine-to-machine, with no browser session to carry an Authentik cookie.
        bypassAuthPaths = [ "^/api" ];
        inherit port global;
        label = "Sonarr";
        icon = "sonarr.svg";
        homepage = {
          group = "Arr Stack";
          description = "Show organizer/manager";
          widget = {
            type = "sonarr";
            # Hit Sonarr directly rather than through nginx/Authentik, since Homepage's
            # server-side widget fetch has no browser session to pass the forward-auth gate.
            url = "http://127.0.0.1:${toString port}";
            api-key = true;
            enableQueue = true;
          };
        };
      };

      secrets = { secrets, ... }: {
        sonarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
          settings.homepage = "sonarr";
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

      nixos = { config, ... }: {
        users.users = {
          sonarr.extraGroups = [ "qbittorrent" ];
        }
        // (lib.genAttrs administrators (user: {
          extraGroups = [ "sonarr" ];
        }));

        services.sonarr = {
          enable = true;
          environmentFiles = [ config.age.secrets."sonarr.env".path ];
          # Sonarr only reaches this vhost via nginx over loopback (its port isn't opened in the
          # firewall), so every request it sees is "local" — this drops Sonarr's own login screen
          # in favor of the Authentik forward-auth gate in front of it, rather than stacking both.
          settings.auth.required = "DisabledForLocalAddresses";
        };
      };
    };
}
