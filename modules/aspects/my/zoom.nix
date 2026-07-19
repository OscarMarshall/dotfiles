{ den, ... }: {
  my.zoom = {
    homeManager = { pkgs, ... }: { home.packages = [ pkgs.zoom-us ]; };
    includes = [ (den._.unfree [ "zoom" ]) ];
  };
}
