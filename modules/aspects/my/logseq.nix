{ inputs, ... }: {
  flake-file = {
    inputs.nix-logseq-git-flake = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Bad3r/nix-logseq-git-flake";
    };
    nixConfig = {
      extra-substituters = [ "https://nix-logseq-git-flake.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-logseq-git-flake.cachix.org-1:DSBNW07PSRyCvS926tpIWahb53OIydwwZhsP6LhJNZo="
      ];
    };
  };

  my.logseq =
    {
      cli-only ? false,
      ...
    }:
    {
      homeManager = { lib, pkgs, ... }: {
        home.packages = [
          inputs.nix-logseq-git-flake.packages.${pkgs.stdenv.hostPlatform.system}.logseq-cli
        ]
        ++ lib.optional (
          !cli-only
        ) inputs.nix-logseq-git-flake.packages.${pkgs.stdenv.hostPlatform.system}.logseq;
      };
    };
}
