{
  my.bat.homeManager =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        extraPackages = builtins.attrValues pkgs.bat-extras;
      };
    };
}
