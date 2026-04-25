{ den, ... }:
{
  my.slack = {
    includes = [ (den._.unfree [ "slack" ]) ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [ slack ];
      };
  };
}
