{ inputs, ... }:
let
  stylix-config =
    { config, pkgs, ... }:
    {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      image = config.lib.stylix.pixel "base0A";
    };
in
{
  flake-file.inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs = {
      home-manager.follows = "home-manager";
      nixpkgs.follows = "nixpkgs";
    };
  };

  my.stylix = {
    darwin = context: {
      imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
      stylix = stylix-config context;
    };

    nixos = context: {
      imports = [ (inputs.stylix.nixosModules.stylix or { }) ];
      stylix = stylix-config context;
    };
  };
}
