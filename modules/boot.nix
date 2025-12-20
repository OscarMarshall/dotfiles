{ ... }:

{
  boot = {
    kernelModules = [ "coretemp" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "zfs" ];
    zfs = {
      extraPools = [ "metalminds" ];
      forceImportRoot = false;
    };
  };
}
