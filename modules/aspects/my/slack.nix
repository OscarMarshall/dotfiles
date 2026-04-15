{ den, ... }:
{
  my.slack = {
    includes = [ (den._.unfree [ "slack" ]) ];
    darwin.homebrew.casks = [ "slack" ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [ slack ];
      };
  };
}
