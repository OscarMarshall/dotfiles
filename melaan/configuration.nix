_: {
  imports = [
    ./hardware-configuration.nix
    ../cachix.nix
    ../modules/users.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/desktop.nix
    ./modules/system.nix
    ./modules/users.nix
  ];
}
