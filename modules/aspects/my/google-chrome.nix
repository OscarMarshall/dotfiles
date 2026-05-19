{ den, ... }:
{
  my.chrome = {
    includes = [ (den._.unfree [ "google-chrome" ]) ];

    hmLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.google-chrome ];
      };
  };
}
