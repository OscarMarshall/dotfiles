let
  port = 8181;
in
{
  my.tautulli =
    {
      global ? false,
    }:
    { host, ... }: {
      nixos = {
        services.tautulli = {
          inherit port;
          enable = true;
        };
      };
      virtual-host = {
        inherit port global;
        group = "Infra";
        homepage = {
          description = "Plex monitoring & stats";
        };
        host = host.name;
        icon = "tautulli.svg";
        label = "Tautulli";
        name = "tautulli";
        protected = true;
      };
    };
}
