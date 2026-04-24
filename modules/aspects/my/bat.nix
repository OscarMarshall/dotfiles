{
  my.bat.homeManager =
    { pkgs, ... }:
    let
      nocheck = pkg: pkg.overrideAttrs (_: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });
    in
    {
      programs.bat = {
        enable = true;
        extraPackages = map nocheck (
          with pkgs.bat-extras;
          [
            batdiff
            batgrep
            batman
            batpipe
            batwatch
            prettybat
          ]
        );
      };
    };
}
