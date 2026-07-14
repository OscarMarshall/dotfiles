let
  port = 8181;
in
{
  my.tautulli =
    {
      global ? false,
    }:
    { host, ... }: {
      virtual-host = {
        name = "tautulli";
        host = host.name;
        protected = true;
        inherit port global;
        homepage = {
          group = "Media";
          label = "Tautulli";
          description = "Plex monitoring & stats";
        };
      };

      nixos = {
        services.tautulli = {
          enable = true;
          inherit port;
        };
      };
    };
}
