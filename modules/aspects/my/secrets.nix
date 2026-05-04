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
        { config, pkgs, ... }:
        {
          imports = [
            (inputs.ragenix.nixosModules.default or { })
            (inputs.agenix-rekey.nixosModules.default or { })
          ];

          age = {
            rekey = rekey host pkgs;

            secrets = {
              oscar-password = {
                rekeyFile = ../../../secrets/oscar-password.age;
                intermediary = true;
              };

              oscar-hashed-password.generator = {
                dependencies = { inherit (config.age.secrets) oscar-password; };
                script =
                  {
                    decrypt,
                    deps,
                    lib,
                    pkgs,
                    ...
                  }:
                  ''
                    ${pkgs.mkpasswd}/bin/mkpasswd "$(${decrypt} ${lib.escapeShellArg deps.oscar-password.file})"
                  '';
              };
            };
          };
        };
    };
}
