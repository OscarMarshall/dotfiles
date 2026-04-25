{ inputs, ... }:

{
  flake-file.inputs.git-hooks = {
    url = "github:cachix/git-hooks.nix";
    inputs = {
      flake-compat.follows = "flake-compat";
      nixpkgs.follows = "nixpkgs";
    };
  };

  imports = [ (inputs.git-hooks.flakeModule or { }) ];

  perSystem =
    { config, pkgs, inputs', ... }:
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = [ config.pre-commit.devShell ];
        packages = [
          inputs'.ragenix.packages.default
          inputs'.agenix-rekey.packages.default
        ];
      };

      pre-commit = {
        check.enable = true;
        settings.hooks = {
          flake-checker.enable = true;
          treefmt.enable = true;
        };
      };
    };
}
