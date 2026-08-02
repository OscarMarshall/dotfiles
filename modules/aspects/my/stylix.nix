{ inputs, ... }: {
  flake-file.inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.stylix = {
    darwin.imports = [ (inputs.stylix.darwinModules.stylix or { }) ];
    homeManager = { home, ... }: builtins.seq home { imports = [ (inputs.stylix.homeModules.stylix or { }) ]; };

    nixos = {
      imports = [ (inputs.stylix.nixosModules.stylix or { }) ];
      # No host uses greetd/regreet as its greeter (melaan is GDM, harmony is headless), and
      # stylix's regreet target still writes to the `programs.regreet` option nixpkgs renamed to
      # `services.displayManager.regreet`, which triggers an obsolete-option warning on every
      # Linux host since the target auto-enables regardless of whether regreet is in use.
      stylix.targets.regreet.enable = false;
    };

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
