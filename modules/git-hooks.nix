{ inputs, lib, ... }:

{
  flake-file.inputs.git-hooks.url = "github:cachix/git-hooks.nix";

  imports = lib.optionals (inputs ? git-hooks) [ inputs.git-hooks.flakeModule ];

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
