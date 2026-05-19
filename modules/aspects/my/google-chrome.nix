{ den, ... }:
{
  my.chrome = {
    includes = [ (den._.unfree [ "google-chrome" ]) ];

    homeManager =
      { lib, pkgs, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.google-chrome ];
      };
  };
}
