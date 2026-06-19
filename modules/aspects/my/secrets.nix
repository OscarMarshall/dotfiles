{ inputs, lib, ... }:
let
  rekey = name: pkgs: {
    masterIdentities = [ ../../../secrets/yubikey-identity.pub ];
    agePlugins = [ pkgs.age-plugin-yubikey ];
    storageMode = "local";
    localStorageDir = ../../../. + "/secrets/rekeyed/${name}";
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
    # user is non-null only in user-entity context (user on a host). We check
    # this to avoid applying darwin/nixos age.rekey twice — once at host level
    # and again at the user level, which would cause a duplicate-definition error.
    {
      host ? null,
      home ? null,
      user ? null,
      ...
    }:
    let
      # For standalone homes (host = null), use home.hostName as the rekey target name.
      entityName =
        if host != null then
          host.name
        else if home != null then
          home.hostName or home.name
        else
          null;
      # Only set OS-level rekey from the host entity itself, not from user entities.
      isHostEntity = user == null && host != null;
    in
    {
      homeManager =
        { lib, pkgs, ... }:
        {
          imports = [
            (inputs.ragenix.homeManagerModules.default or { })
            (inputs.agenix-rekey.homeManagerModules.default or { })
          ];
        }
        // lib.optionalAttrs (entityName != null) { age.rekey = rekey entityName pkgs; };
    }
    // lib.optionalAttrs isHostEntity {
      darwin = { pkgs, ... }: {
        imports = [
          (inputs.ragenix.darwinModules.default or { })
          (inputs.agenix-rekey.darwinModules.default or { })
        ];

        age.rekey = rekey host.name pkgs;
      };

      nixos = { pkgs, ... }: {
        imports = [
          (inputs.ragenix.nixosModules.default or { })
          (inputs.agenix-rekey.nixosModules.default or { })
        ];

        age.rekey = rekey host.name pkgs;
      };
    };
}
