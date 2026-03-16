# NOTE: I'd prefer to use pkgs.prusa-slicer for darwin, but it's currently broken.

{ lib, ... }:
{
  my.prusa-slicer = {
    includes = [
      (
        { host, ... }:
        {
          homeManager =
            { pkgs, ... }:
            {
              home.packages = with pkgs; lib.optionals (host.class != "darwin") [ prusa-slicer ];
            };
        }
      )
    ];

    darwin.homebrew.casks = [ "prusaslicer" ];
  };
}
