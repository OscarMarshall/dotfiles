{ inputs, ... }:

{
  flake-file.inputs.nix-logseq-git-flake = {
    url = "github:Bad3r/nix-logseq-git-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.logseq.homeManager = { pkgs, ... }: {
    home.packages = [ inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq ];
  };
}
