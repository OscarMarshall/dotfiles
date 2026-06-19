{ den, ... }: {
  my.zoom = {
    includes = [ (den._.unfree [ "zoom" ]) ];

    homeManager = { pkgs, ... }: { home.packages = [ pkgs.zoom-us ]; };
  };
}
