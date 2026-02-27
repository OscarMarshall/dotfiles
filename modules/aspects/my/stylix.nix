{ inputs, ... }:
let
  stylix-config =
    { pkgs, ... }:
    {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      image = "${inputs.catppuccin-wallpapers}/os/nix-black-4k.png";
    };
in
{
  flake-file.inputs.catppuccin-wallpapers = {
    url = "github:zhichaoh/catppuccin-wallpapers";
    flake = false;
  };

  flake-file.inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs = {
      home-manager.follows = "home-manager";
      nixpkgs.follows = "nixpkgs";
    };
  };

  my.stylix = {
    darwin = context@{ pkgs, ... }: {
      imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
      stylix = stylix-config context;
    };

    nixos = context@{ pkgs, ... }: {
      imports = [ (inputs.stylix.nixosModules.stylix or { }) ];
      stylix = stylix-config context;
    };
  };
}
