{
  my.bat.homeManager =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        extraPackages = [ pkgs.bat-extras.bat-extras ];
      };
    };
}
