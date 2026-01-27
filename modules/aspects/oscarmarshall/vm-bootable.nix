let
  installer = variant: {
    includes = [ ];
    nixos =
      { modulesPath, ... }:
      {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-${variant}.nix") ];
      };
  };
in
{
  # make USB/VM installers.
  oscarmarshall.vm-bootable = {
    includes = [ ];
    provides = {
      tui = installer "minimal";
      gui = installer "graphical-base";
    };
  };
}
