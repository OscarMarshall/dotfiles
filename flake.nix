# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  inputs = {
    agenix-rekey = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:oddlama/agenix-rekey";
    };
    authentik-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/authentik-nix";
    };
    catppuccin-wallpapers = {
      flake = false;
      url = "github:zhichaoh/catppuccin-wallpapers";
    };
    claude-code-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:sadjow/claude-code-nix";
    };
    codex-cli-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:sadjow/codex-cli-nix";
    };
    darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-darwin/nix-darwin";
    };
    den.url = "github:denful/den";
    flake-compat.url = "github:NixOS/flake-compat";
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    git-hooks = {
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:cachix/git-hooks.nix";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    import-tree.url = "github:vic/import-tree";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nix-doom-emacs-unstraightened = {
      inputs = {
        doomdir.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
      url = "github:marienz/nix-doom-emacs-unstraightened";
    };
    nix-index-database = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nix-index-database";
    };
    nix-logseq-git-flake = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Bad3r/nix-logseq-git-flake";
    };
    nix-minecraft = {
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
      url = "github:Infinidoge/nix-minecraft";
    };
    nixos-hardware = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:NixOS/nixos-hardware";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    pedantix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Swarsel/pedantix";
    };
    ragenix = {
      inputs = {
        agenix.inputs = {
          darwin.follows = "darwin";
          home-manager.follows = "home-manager";
          nixpkgs.follows = "nixpkgs";
          systems.follows = "systems";
        };
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:yaxitech/ragenix";
    };
    stylix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/stylix";
    };
    systems.url = "github:nix-systems/default";
    terranix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:terranix/terranix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
    zen-browser = {
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:0xc000022070/zen-browser-flake";
    };
  };
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://oscarmarshall.cachix.org"
      "https://nix-logseq-git-flake.cachix.org"
      "https://attic.xuyh0120.win/lantian"
      "https://cache.xinux.uz"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "oscarmarshall.cachix.org-1:Fa13vGeBXoJ7jWpvnalg/PCRTtvCpyuHUFL5jQXt/9w="
      "nix-logseq-git-flake.cachix.org-1:DSBNW07PSRyCvS926tpIWahb53OIydwwZhsP6LhJNZo="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
    ];
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
