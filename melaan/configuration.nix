_: {
  imports = [
    ./hardware-configuration.nix
    ../cachix.nix
    ../modules/boot.nix
    ../modules/desktop.nix
    ../modules/networking.nix
    ../modules/system.nix
    ../modules/users.nix
  ];

  # Set hostname for this system
  networking.hostName = "melaan";
}
