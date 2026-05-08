# NOTE: I'd prefer to use pkgs.prusa-slicer for darwin, but it's currently broken.

{
  my.prusa-slicer = {
    hmLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.prusa-slicer ];
      };

    darwin.homebrew.casks = [ "prusaslicer" ];
  };
}
