{inputs, ...}: {
  imports = [
    ../../cachix.nix
    ../../modules/darwin-homebrew.nix
    ../../modules/darwin-packages.nix
    ../../modules/darwin-system.nix
    ../../modules/darwin-users.nix
    ../../modules/nixpkgs.nix
    ../../modules/system.nix
  ];

  # Set hostname for this system
  networking.hostName = "omarshal-m-2fd2";
}
