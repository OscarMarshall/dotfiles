{ lib, my, ... }:
{
  my.radarr =
    let
      port = 7878;
    in
    { administrators }:
    {
      includes = with my; [ (nginx._.virtual-host "radarr.harmony.silverlight-nex.us" port) ];

      nixos = {
        users.users = {
          radarr.extraGroups = [ "qbittorrent" ];
        }
        // (lib.genAttrs administrators (user: {
          extraGroups = [ "radarr" ];
        }));

        services.radarr.enable = true;
      };
    };
}
