{ my, ... }:
{
  my.prowlarr =
    let
      port = 9696;
    in
    {
      includes = with my; [ (nginx._.virtual-host "prowlarr.harmony.silverlight-nex.us" port) ];

      secrets =
        { secrets, ... }:
        {
          prowlarr-api-key = {
            generator.script = "alnum";
            intermediary = true;
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

      nixos =
        { config, ... }:
        {
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
