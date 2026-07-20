{ inputs, ... }: {
  flake-file.inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.stylix = {
    darwin.imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
    homeManager = { home, ... }: builtins.seq home { imports = [ (inputs.stylix.homeModules.stylix or { }) ]; };
    nixos.imports = [ (inputs.stylix.nixosModules.stylix or { }) ];

    os = { pkgs, ... }: {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

        opacity = {
          applications = 0.95;
          popups = 0.95;
          terminal = 0.95;
        };
      };
    };
  };
}
