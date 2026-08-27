# PLACEHOLDER - REGENERATE ON THE MACHINE.
#
# Run `nixos-generate-config --no-filesystems --root /mnt` during install and copy the non-
# filesystem bits (initrd modules, kernel modules, microcode) here, keeping the
# `den.aspects.tensoon.nixos = …` wrapper. Disk layout, `fileSystems`, `swapDevices` and the LUKS
# initrd entries all come from disko (see disk.nix) - do NOT add a `fileSystems` block here.
{
  den.aspects.tensoon.nixos =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot = {
        extraModulePackages = [ ];

        initrd = {
          availableKernelModules = [
            "xhci_pci"
            "thunderbolt"
            "nvme"
            "usb_storage"
            "sd_mod"
          ];

          kernelModules = [ ];
        };

        kernelModules = [ "kvm-intel" ];
      };

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
