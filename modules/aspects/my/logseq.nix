{ inputs, ... }: {
  flake-file = {
    inputs.nix-logseq-git-flake = {
      url = "github:Bad3r/nix-logseq-git-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixConfig = {
      extra-substituters = [ "https://nix-logseq-git-flake.cachix.org" ];
      extra-trusted-public-keys = [ "nix-logseq-git-flake.cachix.org-1:DSBNW07PSRyCvS926tpIWahb53OIydwwZhsP6LhJNZo=" ];
    };
  };

  my.logseq =
    {
      cli-only ? false,
      ...
    }:
    {
      homeManager = { pkgs, lib, ... }: {
        home.packages = [
          inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli
        ]
        ++ lib.optional (!cli-only) inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq;
      };
    };
}
