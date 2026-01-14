{
  flake.modules.nixos.lm_sensors = {pkgs, ...}: {
    # Enable coretemp kernel module for temperature monitoring
    boot.kernelModules = ["coretemp"];

    # Install lm_sensors for hardware monitoring
    environment.systemPackages = with pkgs; [lm_sensors];
  };
}
