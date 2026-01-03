{inputs, ...}: {
  imports = [
    ../../cachix.nix
    ../../modules/homebrew.nix
    ../../modules/nixpkgs.nix
    ../../modules/steam.nix
    ../../modules/system.nix
    ../../modules/users.nix
  ];

  # Set hostname for this system
  networking.hostName = "omarshal-m-2fd2";
}
