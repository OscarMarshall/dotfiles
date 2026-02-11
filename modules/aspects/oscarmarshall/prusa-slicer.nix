# NOTE: I'd prefer to use pkgs.prusa-slicer for darwin, but it's currently broken.

{ den, lib, ... }:
{
  oscarmarshall.prusa-slicer = den.lib.parametric {
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
