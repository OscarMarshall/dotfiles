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
      homeManager = { pkgs, lib, ... }: {
        home.packages = [
          inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli
        ]
        ++ lib.optional (!cli-only) inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq;
      };
    };
}
