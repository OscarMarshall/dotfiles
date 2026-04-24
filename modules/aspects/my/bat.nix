{
  my.bat.homeManager =
    { lib, pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        extraPackages = lib.filter lib.isDerivation (builtins.attrValues pkgs.bat-extras);
      };
    };
}
