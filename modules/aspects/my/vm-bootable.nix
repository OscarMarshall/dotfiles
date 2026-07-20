let
  installer = variant: {
    nixos = { modulesPath, ... }: { imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-${variant}.nix") ]; };
  };
in
{
  # make USB/VM installers.
  my.vm-bootable.provides = {
    gui = installer "graphical-base";
    tui = installer "minimal";
  };
}
