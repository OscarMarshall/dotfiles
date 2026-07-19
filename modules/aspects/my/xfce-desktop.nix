{
  my.xfce-desktop.nixos = { lib, ... }: {
    # https://gist.github.com/nat-418/1101881371c9a7b419ba5f944a7118b0
    services = {
      displayManager = {
        defaultSession = lib.mkDefault "xfce";
        enable = true;
      };
      xserver = {
        desktopManager = {
          xfce.enable = true;
          xterm.enable = false;
        };
        enable = true;
      };
    };
  };
}
