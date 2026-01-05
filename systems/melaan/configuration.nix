_: {
  imports = [
    ./hardware-configuration.nix
    ../../cachix.nix
    ../modules/boot.nix
    ../modules/flatpak.nix
    ../modules/fonts.nix
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
