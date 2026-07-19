{ lib, ... }: {
  my.boot.nixos = { pkgs, ... }: {
    boot = {
      # Use latest kernel for all systems (lowest priority, can be overridden)
      kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          # Without a limit, every generation's kernel+initrd accumulates on the EFI System
          # Partition until it fills up, at which point a new generation's files can be written
          # incompletely and fail to boot with "Switch root target contains no usable init".
          configurationLimit = lib.mkDefault 10;
          enable = true;
        };
      };
    };
  };
}
