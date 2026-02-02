{ lib, oscarmarshall, ... }:
{
  oscarmarshall.sonarr =
    let
      port = 8989;
    in
    { administrators }:
    {
      includes = with oscarmarshall; [ (nginx._.virtual-host "sonarr.harmony.silverlight-nex.us" port) ];

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
