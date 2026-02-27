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
    darwin =
      { config, pkgs, ... }:
      {
        imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
        stylix = {
          enable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
          image = config.lib.stylix.pixel "1e1e2e";
        };
      };

    nixos =
      { config, pkgs, ... }:
      {
        imports = [ (inputs.stylix.nixosModules.stylix or { }) ];
        stylix = {
          enable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
          image = config.lib.stylix.pixel "1e1e2e";
        };
      };
  };
}
