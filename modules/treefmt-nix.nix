{ inputs, ... }:

{
  flake-file.inputs.treefmt-nix = {
    url = "github:numtide/treefmt-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [ (inputs.treefmt-nix.flakeModule or { }) ];

  perSystem.treefmt = {
    flakeFormatter = true;
    programs = {
      nixf-diagnose.enable = true;
      nixfmt = {
        enable = true;
        strict = true;
        width = 120;
      };
      prettier = {
        enable = true;
        settings = {
          printWidth = 120;
          proseWrap = "always";
        };
      };
    };
  };
}
