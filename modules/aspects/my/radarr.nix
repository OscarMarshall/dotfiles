{ lib, my, ... }:
let
  port = 7878;
in
{
  my.radarr = { administrators }: {
    includes = with my; [ (nginx._.virtual-host "radarr.harmony.silverlight-nex.us" port) ];

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
