{ lib, ... }:
let
  url = "radarr.harmony.silverlight-nex.us";
  port = 7878;
in
{
  my.radarr = { administrators }: {
    virtual-host = {
      name = "radarr";
      protected = true;
      # Radarr serves its REST API under /api; nginx.nix lets that through the Authentik
      # forward-auth gate untouched since cross-seed/unpackerr call it directly with an API key,
      # machine-to-machine, with no browser session to carry an Authentik cookie.
      bypassAuthPaths = [ "^/api" ];
      inherit url port;
    };

    homepage-entry = {
      group = "Arr Stack";
      label = "Radarr";
      description = "Movie organizer/manager";
      href = "https://${url}";
      widget = {
        type = "radarr";
        # Hit Radarr directly rather than through nginx/Authentik, since Homepage's server-side
        # widget fetch has no browser session to pass the forward-auth gate.
        url = "http://127.0.0.1:${toString port}";
        key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
        enableQueue = true;
      };
    };

    secrets = { secrets, ... }: {
      radarr-api-key = {
        generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
        intermediary = true;
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

    nixos = { config, ... }: {
      users.users = {
        radarr.extraGroups = [ "qbittorrent" ];
      }
      // (lib.genAttrs administrators (user: {
        extraGroups = [ "radarr" ];
      }));

      services.radarr = {
        enable = true;
        environmentFiles = [ config.age.secrets."radarr.env".path ];
        # Radarr only reaches this vhost via nginx over loopback (its port isn't opened in the
        # firewall), so every request it sees is "local" — this drops Radarr's own login screen in
        # favor of the Authentik forward-auth gate in front of it, rather than stacking both.
        settings.auth.required = "DisabledForLocalAddresses";
      };
    };
  };
}
