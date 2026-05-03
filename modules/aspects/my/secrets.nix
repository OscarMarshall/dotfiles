{ inputs, ... }:
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

  my.secrets.nixos =
    { pkgs, ... }:
    {
      imports = [
        (inputs.ragenix.nixosModules.default or { })
        (inputs.agenix-rekey.nixosModules.default or { })
      ];

      age.rekey = {
        masterIdentities = [ ../../../secrets/yubikey-identity.pub ];
        agePlugins = [ pkgs.age-plugin-yubikey ];
        storageMode = "local";
      };
    };
}
