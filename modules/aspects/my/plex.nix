{ den, ... }:
let
  url = "plex.harmony.silverlight-nex.us";
in
{
  my.plex = {
    includes = [ (den._.unfree [ "plexmediaserver" ]) ];

    virtual-host = {
      name = "plex";
      inherit url;
      port = 32400;
    };

    homepage-entry = {
      group = "Media";
      label = "Plex";
      description = "Media server";
      href = "https://${url}";
    };

    nixos = {
      services.plex = {
        enable = true;
        openFirewall = true;
      };
    };
  };
}
