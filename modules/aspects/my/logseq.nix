{ inputs, ... }:

{
  flake-file.inputs.nix-logseq-git-flake = {
    url = "github:Bad3r/nix-logseq-git-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.logseq =
    {
      cli-only ? false,
      ...
    }:
    {
      substituters = [
        {
          substituter = "https://nix-logseq-git-flake.cachix.org";
          publicKey = "nix-logseq-git-flake.cachix.org-1:DSBNW07PSRyCvS926tpIWahb53OIydwwZhsP6LhJNZo=";
        }
      ];

      homeManager = { pkgs, lib, ... }: {
        home.packages = [
          inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli
        ]
        ++ lib.optional (!cli-only) inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq;
      };
    };
}
