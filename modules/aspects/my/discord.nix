{ den, ... }:
{
  my.discord = {
    includes = [ (den._.unfree [ "discord" ]) ];

    darwin.homebrew.casks = [ "discord" ];

    hmLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.discord ];
      };
  };
}
