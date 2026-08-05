{
  my.mkvtoolnix = {
    darwin.homebrew.casks = [ "mkvtoolnix-app" ];
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.mkvtoolnix ]; };
  };
}
