{ lib, my, ... }:
{
  my.sonarr =
    let
      port = 8989;
    in
    { administrators }:
    {
      includes = with my; [ (nginx._.virtual-host "sonarr.harmony.silverlight-nex.us" port) ];

      nixos =
        { config, ... }:
        {
          age.secrets = {
            sonarr-api-key = {
              rekeyFile = ../../../secrets/sonarr-api-key.age;
              generator.script = "alnum";
              intermediary = true;
            };
            "sonarr.env" = {
              rekeyFile = ../../../secrets/sonarr.env.age;
              generator = {
                dependencies = { inherit (config.age.secrets) sonarr-api-key; };
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
          };

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
