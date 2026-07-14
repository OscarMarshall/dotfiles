let
  url = "tautulli.harmony.silverlight-nex.us";
  port = 8181;
in
{
  my.tautulli = {
    virtual-host = {
      name = "tautulli";
      protected = true;
      inherit url port;
    };

    homepage-entry = {
      group = "Media";
      label = "Tautulli";
      description = "Plex monitoring & stats";
      href = "https://${url}";
    };

    nixos = {
      services.tautulli = {
        enable = true;
        inherit port;
      };
    };
  };
}
