{
  my.orca-slicer = {
    darwin.homebrew.casks = [ "orcaslicer" ];
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.orca-slicer ]; };
  };
}
