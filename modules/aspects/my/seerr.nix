let
  port = 5055;
in
{
  my.seerr =
    {
      global ? false,
    }:
    { host, ... }: {
      virtual-host = {
        name = "seerr";
        host = host.name;
        inherit port global;
        homepage = {
          group = "Media";
          label = "Seerr";
          description = "Media requests";
        };
      };

      nixos.services.seerr = {
        enable = true;
        inherit port;
      };
    };
}
