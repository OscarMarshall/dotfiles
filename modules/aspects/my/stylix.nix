{ inputs, ... }:
let
  stylix-config =
    { pkgs, ... }:
    {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      # Avoid infinite recursion: config.lib.stylix.pixel depends on
      # config.lib.stylix.colors, which the module system would try to evaluate
      # while type-checking this option, creating a cycle.
      image = pkgs.runCommand "stylix-background.png" { } ''
        ${pkgs.imagemagick}/bin/convert xc:#1e1e2e png32:$out
      '';
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
    darwin = context@{ config, pkgs, ... }: {
      imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
      stylix = stylix-config context;
    };

    nixos = context@{ config, pkgs, ... }: {
      imports = [ (inputs.stylix.nixosModules.stylix or { }) ];
      stylix = stylix-config context;
    };
  };
}
