{inputs, ...}: {
  imports = [
    ../../cachix.nix
    ../modules/fonts.nix
    ../modules/homebrew.nix
    ../modules/nixpkgs.nix
    ../modules/steam.nix
    ../modules/system.nix
    ../modules/users.nix
  ];

  # Set hostname for this system
  networking.hostName = "omarshal-m-2fd2";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
