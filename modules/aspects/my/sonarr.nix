{ lib, my, ... }:
{
  my.sonarr =
    let
      port = 8989;
    in
    { administrators }:
    {
      includes = with my; [ (nginx._.virtual-host "sonarr.harmony.silverlight-nex.us" port) ];

      nixos = {
        users.users = {
          sonarr.extraGroups = [ "qbittorrent" ];
        }
        // (lib.genAttrs administrators (user: {
          extraGroups = [ "sonarr" ];
        }));

        services.sonarr.enable = true;
      };
    };
}
