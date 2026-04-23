{
  my.orca-slicer = {
    hmLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.orca-slicer ];
      };

    darwin.homebrew.casks = [ "orcaslicer" ];
  };
}
