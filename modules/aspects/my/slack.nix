{ den, lib, ... }:
{
  my.slack = {
    includes = [ (den._.unfree [ "slack" ]) ];

    darwin.homebrew.casks = [ "slack" ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.isLinux (with pkgs; [ slack ]);
      };
  };
}
