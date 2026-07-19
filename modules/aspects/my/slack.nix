{ den, ... }: {
  my.slack = {
    homeManager = { pkgs, ... }: { home.packages = with pkgs; [ slack ]; };
    includes = [ (den._.unfree [ "slack" ]) ];
  };
}
