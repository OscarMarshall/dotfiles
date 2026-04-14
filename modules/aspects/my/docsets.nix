{ lib, ... }:
{
  my.docsets = {
    darwin.homebrew.casks = [ "dash" ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.zeal ];
      };
  };
}
