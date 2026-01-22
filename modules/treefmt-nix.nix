{ inputs, lib, ... }:

{
  flake-file.inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  imports = lib.optionals (inputs ? treefmt-nix) [ inputs.treefmt-nix.flakeModule ];

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
