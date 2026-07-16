{ den, ... }: {
  my.plex =
    {
      global ? false,
    }:
    { host, ... }: {
      includes = [ (den._.unfree [ "plexmediaserver" ]) ];

      virtual-host = {
        name = "plex";
        host = host.name;
        port = 32400;
        inherit global;
        homepage = {
          group = "Media";
          label = "Plex";
          description = "Media server";
          icon = "plex.svg";
        };
      };

      port-forward = {
        name = "plex";
        port = 32400;
      };

      nixos = {
        services.plex = {
          enable = true;
          openFirewall = true;
        };
      };
    };
}
