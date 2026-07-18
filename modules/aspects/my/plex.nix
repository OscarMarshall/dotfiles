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
        label = "Plex";
        icon = "plex.svg";
        group = "Media";
        homepage = {
          description = "Media server";
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
