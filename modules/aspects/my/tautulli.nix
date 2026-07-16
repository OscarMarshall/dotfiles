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
        label = "Tautulli";
        icon = "tautulli.svg";
        group = "Media";
        homepage = {
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
