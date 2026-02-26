{ lib, ... }:
{
  my.boot.nixos =
    { pkgs, ... }:
    {
      boot = {
        # Use latest kernel for all systems (lowest priority, can be overridden)
        kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      };
    };
}
