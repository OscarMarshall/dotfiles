{ inputs, ... }:
let
  stylix-config = pkgs: {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
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
    darwin =
      { pkgs, ... }:
      {
        imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
        stylix = stylix-config pkgs;
      };

    nixos =
      { pkgs, ... }:
      {
        imports = [ (inputs.stylix.nixosModules.stylix or { }) ];
        stylix = stylix-config pkgs;
      };
  };
}
