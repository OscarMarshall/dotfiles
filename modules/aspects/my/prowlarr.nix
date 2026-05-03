{ my, ... }:
{
  my.prowlarr =
    let
      port = 9696;
    in
    {
      includes = with my; [ (nginx._.virtual-host "prowlarr.harmony.silverlight-nex.us" port) ];

      nixos =
        { config, ... }:
        {
          age.secrets = {
            prowlarr-api-key = {
              rekeyFile = ../../../secrets/prowlarr-api-key.age;
              generator.script = "alnum";
              intermediary = true;
            };
            "prowlarr.env" = {
              rekeyFile = ../../../secrets/prowlarr.env.age;
              generator = {
                dependencies = { inherit (config.age.secrets) prowlarr-api-key; };
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
          };

          services = {
            prowlarr = {
              enable = true;
              settings.server = { inherit port; };
              environmentFiles = [ config.age.secrets."prowlarr.env".path ];
            };
            flaresolverr.enable = true;
          };
        };
    };
}
