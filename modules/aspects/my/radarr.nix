{ lib, my, ... }:
let
  port = 7878;
in
{
  my.radarr =
    { administrators }:
    {
      includes = with my; [ (nginx._.virtual-host "radarr.harmony.silverlight-nex.us" port) ];

      nixos =
        { config, ... }:
        {
          age.secrets = {
            radarr-api-key = {
              rekeyFile = ../../../secrets/radarr-api-key.age;
              generator.script = "alnum";
              intermediary = true;
            };
            "radarr.env" = {
              rekeyFile = ../../../secrets/radarr.env.age;
              generator = {
                dependencies = { inherit (config.age.secrets) radarr-api-key; };
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
          };

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
