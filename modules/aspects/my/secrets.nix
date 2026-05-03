{ inputs, ... }:
let
  config =
    { pkgs, ... }:
    {
      age.rekey = {
        masterIdentities = [ ../../../secrets/yubikey-identity.pub ];
        agePlugins = [ pkgs.age-plugin-yubikey ];
        storageMode = "local";
      };
    };
in
{
  flake-file.inputs = {
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs = {
        agenix.inputs = {
          darwin.follows = "darwin";
          home-manager.follows = "home-manager";
          nixpkgs.follows = "nixpkgs";
          systems.follows = "systems";
        };
        nixpkgs.follows = "nixpkgs";
      };
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  my.secrets = {
    darwin =
      inputs':
      {
        imports = [
          (inputs.ragenix.darwinModules.default or { })
          (inputs.agenix-rekey.darwinModules.default or { })
        ];
      }
      // (config inputs');

    nixos =
      inputs':
      {
        imports = [
          (inputs.ragenix.nixosModules.default or { })
          (inputs.agenix-rekey.nixosModules.default or { })
        ];
      }
      // (config inputs');

    homeManager =
      inputs':
      {
        imports = [
          (inputs.ragenix.homeManagerModules.default or { })
          (inputs.agenix-rekey.homeManagerModules.default or { })
        ];
      }
      // (config inputs');
  };
}
