{
  config,
  lib,
  pkgs,
  ...
}: {
  boot = {
    kernelModules = lib.mkIf (config.networking.hostName == "harmony") ["coretemp"];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    # Use latest kernel for melaan (Framework laptop)
    kernelPackages = lib.mkIf (config.networking.hostName == "melaan") pkgs.linuxPackages_latest;
  };
}
