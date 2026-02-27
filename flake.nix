# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    catppuccin-wallpapers = {
      flake = false;
      url = "github:zhichaoh/catppuccin-wallpapers";
    };
    darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-darwin/nix-darwin";
    };
    den.url = "github:vic/den";
    flake-aspects.url = "github:vic/flake-aspects";
    flake-compat.url = "github:NixOS/flake-compat";
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
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
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
      url = "github:marienz/nix-doom-emacs-unstraightened";
    };
    nix-minecraft = {
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
      url = "github:Infinidoge/nix-minecraft";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-lib.follows = "nixpkgs";
    ragenix = {
      inputs = {
        agenix.inputs = {
          darwin.follows = "darwin";
          flake-utils.inputs.systems.follows = "systems";
          home-manager.follows = "home-manager";
        };
        flake-utils.inputs.systems.follows = "systems";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:yaxitech/ragenix";
    };
    stylix = {
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:nix-community/stylix";
    };
    systems.url = "github:nix-systems/default";
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

}
