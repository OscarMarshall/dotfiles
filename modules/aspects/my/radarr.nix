{ lib, ... }:
let
  port = 7878;
in
{
  my.radarr =
    {
      administrators,
      global ? false,
    }:
    { host, ... }: {
      virtual-host = {
        name = "radarr";
        host = host.name;
        inherit port global;
        homepage = {
          group = "Arr Stack";
          label = "Radarr";
          description = "Movie organizer/manager";
          widget = {
            type = "radarr";
            apiKeySecret = "radarr-api-key";
            enableQueue = true;
          };
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
        };
      };
    };
}
