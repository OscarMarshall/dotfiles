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
        inherit port global;
        homepage = {
          group = "Arr Stack";
          label = "Sonarr";
          description = "Show organizer/manager";
          widget = {
            type = "sonarr";
            apiKeySecret = "sonarr-api-key";
            enableQueue = true;
          };
        };
      };

      secrets = { secrets, ... }: {
        sonarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
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
        };
      };
    };
}
