{ inputs, ... }:
let
  age.secrets = {
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
  flake-file.inputs.agenix = {
    url = "github:ryantm/agenix";
    inputs = {
      darwin.follows = "darwin";
      home-manager.follows = "home-manager";
      nixpkgs.follows = "nixpkgs";
      systems.follows = "systems";
    };
  };
  flake-file.inputs.agenix-rekey = {
    url = "github:oddlama/agenix-rekey";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.secrets = {
    nixos = {
      imports = [
        (inputs.agenix.nixosModules.default or { })
        (inputs.agenix-rekey.nixosModules.default or { })
      ];
      inherit age;
      age.rekey = {
        masterIdentities = [ ../../../secrets/master.pub ];
        storageMode = "local";
      };
    };
    darwin = {
      imports = [ (inputs.agenix.darwinModules.default or { }) ];
      inherit age;
    };
    homeManager = {
      imports = [ (inputs.agenix.homeManagerModules.default or { }) ];
      inherit age;
    };
  };
}
