{ inputs, ... }:
{
  flake-file.inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.stylix = {
    darwin.imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
    nixos.imports = [ (inputs.stylix.nixosModules.stylix or { }) ];

    os =
      { pkgs, ... }:
      {
        stylix = {
          enable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        };
      };
  };
}
