{ den, ... }:
{
  my.zoom = {
    includes = [ (den._.unfree [ "zoom" ]) ];

    hmLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.zoom-us ];
      };
  };
}
