_: {
  imports = [
    ./hardware-configuration.nix
    ../cachix.nix
    ../modules/boot.nix
    ../modules/flatpak.nix
    ../modules/gnome.nix
    ../modules/networking.nix
    ../modules/nixpkgs.nix
    ../modules/pipewire.nix
    ../modules/printing.nix
    ../modules/steam.nix
    ../modules/system.nix
    ../modules/users.nix
  ];

  # Set hostname for this system
  networking.hostName = "melaan";
}
