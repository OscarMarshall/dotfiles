{
  my.bat.homeManager =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        extraPackages = [
          (pkgs.bat-extras.core.overrideAttrs (_: {
            doCheck = false;
            nativeCheckInputs = [ ];
          }))
        ];
      };
    };
}
