{ my, ... }:
{
  my.autobrr =
    let
      port = 7474;
    in
    {
      includes = [ (my.nginx._.virtual-host "autobrr.harmony.silverlight-nex.us" port) ];

      nixos =
        { config, ... }:
        {
          services.autobrr = {
            enable = true;
            secretFile = config.age.secrets.autobrr-secret.path;
            settings = {
              inherit port;
              checkForUpdates = true;
              host = "127.0.0.1";
            };
          };
        };
    };
}
