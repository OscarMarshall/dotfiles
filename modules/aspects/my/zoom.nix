{ den, ... }:
{
  my.zoom = {
    includes = [ (den._.unfree [ "zoom" ]) ];

    homeManager =
      { lib, pkgs, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.zoom-us ];
      };
  };
}
