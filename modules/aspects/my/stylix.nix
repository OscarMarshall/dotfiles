{ inputs, ... }:
{
  flake-file.inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs = {
      home-manager.follows = "home-manager";
      nixpkgs.follows = "nixpkgs";
    };
  };

  my.stylix = {
    darwin = {
      imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
      stylix.enable = true;
    };

    nixos = {
      imports = [ (inputs.stylix.nixosModules.stylix or { }) ];
      stylix.enable = true;
    };
  };
}
