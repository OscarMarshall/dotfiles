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
        # Higher than the (default 0) priority of nixf-diagnose, pedantix, and statix, so nixfmt
        # runs last and re-formats whatever those passes restructure (e.g. pedantix's attrs.merge
        # / attrs.flatten), keeping it the canonical formatter for indentation and wrapping.
        priority = 1;
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

      statix.enable = true;
    };

    settings.excludes = [ "flake.nix" ];
  };
}
