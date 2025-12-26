{...}: {
  boot = {
    kernelModules = ["coretemp"];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
}
