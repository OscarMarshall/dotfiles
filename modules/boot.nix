{pkgs, ...}: {
  boot = {
    kernelModules = ["coretemp"];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    # Use latest kernel for all systems
    kernelPackages = pkgs.linuxPackages_latest;
  };
}
