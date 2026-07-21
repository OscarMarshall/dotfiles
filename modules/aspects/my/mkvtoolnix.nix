{
  my.mkvtoolnix = {
    darwin.homebrew.casks = [ "mkvtoolnix" ];
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.mkvtoolnix ]; };
  };
}
