{ den, ... }: {
  my.chrome = {
    homeManager = { pkgs, ... }: { home.packages = [ pkgs.google-chrome ]; };
    includes = [ (den._.unfree [ "google-chrome" ]) ];
  };
}
