let
  url = "seerr.harmony.silverlight-nex.us";
  port = 5055;
in
{
  my.seerr = {
    virtual-host = {
      name = "seerr";
      inherit url port;
    };

    homepage-entry = {
      group = "Media";
      label = "Seerr";
      description = "Media requests";
      href = "https://${url}";
    };

    nixos.services.seerr = {
      enable = true;
      inherit port;
    };
  };
}
