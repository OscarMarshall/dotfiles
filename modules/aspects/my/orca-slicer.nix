{ lib, ... }:
{
  my.orca-slicer = {
    includes = [
      (
        { host, ... }:
        {
          homeManager =
            { pkgs, ... }:
            {
              home.packages = with pkgs; lib.optionals (host.class != "darwin") [ orca-slicer ];
            };
        }
      )
    ];

    darwin.homebrew.casks = [ "orcaslicer" ];
  };
}
