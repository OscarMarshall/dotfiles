{ inputs, ... }:
let
  rekey = host: pkgs: {
    masterIdentities = [ ../../../secrets/yubikey-identity.pub ];
    agePlugins = [ pkgs.age-plugin-yubikey ];
    storageMode = "local";
    localStorageDir = ../../../. + "/secrets/rekeyed/${host.name}";
    generatedSecretsDir = ../../../secrets/generated;
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

  my.secrets =
    { host, ... }:
    {
      darwin =
        { pkgs, ... }:
        {
          imports = [
            (inputs.ragenix.darwinModules.default or { })
            (inputs.agenix-rekey.darwinModules.default or { })
          ];

          age.rekey = rekey host pkgs;
        };

      homeManager =
        { pkgs, ... }:
        {
          imports = [
            (inputs.ragenix.homeManagerModules.default or { })
            (inputs.agenix-rekey.homeManagerModules.default or { })
          ];

          age.rekey = rekey host pkgs;
        };

      nixos =
        { pkgs, ... }:
        {
          imports = [
            (inputs.ragenix.nixosModules.default or { })
            (inputs.agenix-rekey.nixosModules.default or { })
          ];

          age.rekey = rekey host pkgs;
        };
    };
}
