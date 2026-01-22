{ oscarmarshall, ... }:
{
  oscarmarshall.prowlarr =
    let
      port = 9696;
    in
    {
      includes = with oscarmarshall; [ (nginx._.virtual-host "prowlarr.harmony.silverlight-nex.us" port) ];

      nixos = {
        services = {
          prowlarr = {
            enable = true;
            settings.server = { inherit port; };
          };
          flaresolverr.enable = true;
        };
      };
    };
}
