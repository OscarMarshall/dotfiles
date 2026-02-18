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
    { config, ... }:
    {
      devShells.default = config.pre-commit.devShell;

      pre-commit = {
        check.enable = true;
        settings.hooks = {
          flake-checker.enable = true;
          treefmt.enable = true;
        };
      };
    };
}
