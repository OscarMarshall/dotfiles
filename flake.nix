{
  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-minecraft = {
      url = "github:OscarMarshall/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs @ {
    agenix,
    git-hooks,
    home-manager,
    nix-darwin,
    nixos-hardware,
    nixpkgs,
    self,
    systems,
    zen-browser,
    ...
  }: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    nixosConfigurations = {
      harmony = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./systems/harmony/configuration.nix
          agenix.nixosModules.default
          {environment.systemPackages = [agenix.packages.x86_64-linux.default];}
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users = {
                oscar = ./homes/oscar.nix;
                adelline = ./homes/adelline.nix;
              };
            };

            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
          }
        ];
      };

      melaan = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./systems/melaan/configuration.nix
          nixos-hardware.nixosModules.framework-12-13th-gen-intel
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users = {
                oscar = ./homes/oscar.nix;
                adelline = ./homes/adelline.nix;
              };
            };
          }
        ];
      };
    };

    darwinConfigurations = {
      OMARSHAL-M-2FD2 = nix-darwin.lib.darwinSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./systems/omarshal-m-2fd2/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.omarshal = ./homes/omarshal.nix;
              extraSpecialArgs = {inherit inputs;};
            };
          }
        ];
      };
    };

    # Run the hooks with `nix fmt`.
    formatter = forEachSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (self.checks.${system}.pre-commit-check) config;
        inherit (config) package configFile;
        script = ''
          ${pkgs.lib.getExe package} run --all-files --config ${configFile}
        '';
      in
        pkgs.writeShellScriptBin "pre-commit-run" script
    );

    # Run the hooks in a sandbox with `nix flake check`.
    # Read-only filesystem and no internet access.
    checks = forEachSystem (system: {
      pre-commit-check = inputs.git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          flake-checker.enable = true;
          statix.enable = true;
          prettier = {
            enable = true;
            settings.write = true;
          };
        };
      };
    });

    # Enter a development shell with `nix develop`.
    # The hooks will be installed automatically.
    # Or run pre-commit manually with `nix develop -c pre-commit run --all-files`
    devShells = forEachSystem (system: {
      default = let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
      in
        pkgs.mkShell {
          inherit shellHook;
          buildInputs = enabledPackages;
        };
    });
  };
}
