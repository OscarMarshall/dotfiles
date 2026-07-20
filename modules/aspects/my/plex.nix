{ den, ... }: {
  my.plex =
    {
      global ? false,
    }:
    { host, ... }: {
      includes = [ (den._.unfree [ "plexmediaserver" ]) ];

      nixos = {
        services.plex = {
          enable = true;
          openFirewall = true;
        };
      };

      port-forward = {
        name = "plex";
        port = 32400;
      };

      virtual-host = {
        inherit global;
        group = "Media";

        homepage = {
          description = "Media server";
        };

        host = host.name;
        icon = "plex.svg";
        label = "Plex";
        name = "plex";
        port = 32400;
      };
    };
}
