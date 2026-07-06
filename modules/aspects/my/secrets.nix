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
      # A user embedded under a host (e.g. oscar's home-manager profile on a host) is a separate
      # agenix-rekey node from that host's own OS-level node. `agenix rekey`'s local storage mode deletes
      # any file in a node's `localStorageDir` that isn't one of that node's own secrets, to clean up
      # orphans. If the OS-level and embedded-user nodes shared a directory (both keyed by `host.name`),
      # whichever node ran last on a given `agenix rekey -a` pass would delete the other's exclusively-owned
      # secrets as "orphans". Giving the embedded user a separate sibling directory keeps each node's
      # cleanup pass scoped to only its own files.
      homeManagerEntityName = if host != null && user != null then "${host.name}-home-${user.userName}" else entityName;
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
        // lib.optionalAttrs (homeManagerEntityName != null) { age.rekey = rekey homeManagerEntityName pkgs; };
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
