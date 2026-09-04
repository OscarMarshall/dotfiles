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

      hardware.cpu.intel = {
        npu.enable = true;
        updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
