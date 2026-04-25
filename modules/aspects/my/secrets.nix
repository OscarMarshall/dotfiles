{ inputs, pkgs, ... }:
let
  ageSecrets = {
    autobrr-secret.rekeyFile = ../../../secrets/autobrr-secret.age;
    "cross-seed.json".rekeyFile = ../../../secrets/cross-seed.json.age;
    "gluetun.env".rekeyFile = ../../../secrets/gluetun.env.age;
    "homepage-dashboard.env".rekeyFile = ../../../secrets/homepage-dashboard.env.age;
    "minecraft-servers.env".rekeyFile = ../../../secrets/minecraft-servers.env.age;
    "qbittorrent.env".rekeyFile = ../../../secrets/qbittorrent.env.age;
    "unpackerr.env".rekeyFile = ../../../secrets/unpackerr.env.age;
  };
in
{
  flake-file.inputs.ragenix = {
    url = "github:yaxitech/ragenix";
    inputs = {
      agenix.inputs = {
        darwin.follows = "darwin";
        flake-utils.inputs.systems.follows = "systems";
        home-manager.follows = "home-manager";
      };
      flake-utils.inputs.systems.follows = "systems";
      nixpkgs.follows = "nixpkgs";
    };
  };
  flake-file.inputs.agenix-rekey = {
    url = "github:oddlama/agenix-rekey";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.secrets = {
    darwin.imports = [ (inputs.ragenix.darwinModules.default or { }) ];
    nixos = {
      imports = [
        (inputs.ragenix.nixosModules.default or { })
        (inputs.agenix-rekey.nixosModules.default or { })
      ];
      age = {
        secrets = ageSecrets;
        rekey = {
          masterIdentities = [ ../../../secrets/yubikey-identity.pub ];
          agePlugins = [ pkgs.age-plugin-yubikey ];
          storageMode = "local";
        };
      };
    };

    homeManager.imports = [ (inputs.ragenix.homeManagerModules.default or { }) ];
  };
}
