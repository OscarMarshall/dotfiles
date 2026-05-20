{ den, ... }:
{
  my.chrome = {
    includes = [ (den._.unfree [ "google-chrome" ]) ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.google-chrome ];
      };
  };
}
