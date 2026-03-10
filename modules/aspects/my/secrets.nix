{ inputs, ... }:
let
  age.secrets = {
    autobrr-secret.file = ../../../secrets/autobrr-secret.age;
    "cross-seed.json".file = ../../../secrets/cross-seed.json.age;
    "gluetun.env".file = ../../../secrets/gluetun.env.age;
    "homepage-dashboard.env".file = ../../../secrets/homepage-dashboard.env.age;
    "minecraft-servers.env".file = ../../../secrets/minecraft-servers.env.age;
    "qbittorrent.env".file = ../../../secrets/qbittorrent.env.age;
    "unpackerr.env".file = ../../../secrets/unpackerr.env.age;
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

  my.secrets = {
    darwin.imports = [ (inputs.ragenix.darwinModules.default or { }) ];
    nixos.imports = [ (inputs.ragenix.nixosModules.default or { }) ];
    os = { inherit age; };

    homeManager = {
      imports = [ (inputs.ragenix.homeManagerModules.default or { }) ];
      inherit age;
    };
  };
}
