{ inputs, ... }: {
  flake-file.inputs.stylix = {
    inputs.nixpkgs.follows = "nixpkgs";
    url = "github:nix-community/stylix";
  };

  my.stylix = {
    darwin.imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
    homeManager =
      { home, ... }: builtins.seq home { imports = [ (inputs.stylix.homeModules.stylix or { }) ]; };
    nixos.imports = [ (inputs.stylix.nixosModules.stylix or { }) ];

    os = { pkgs, ... }: {
      stylix = {
        base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        enable = true;
        opacity = {
          applications = 0.95;
          popups = 0.95;
          terminal = 0.95;
        };
      };
    };
  };
}
