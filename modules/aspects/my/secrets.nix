{ inputs, lib, ... }:
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
  flake-file.inputs.ragenix.url = "github:yaxitech/ragenix";

  my.secrets = {
    nixos = {
      imports = lib.optionals (inputs ? ragenix) [ inputs.ragenix.nixosModules.default ];
      inherit age;
    };
    darwin = {
      imports = lib.optionals (inputs ? ragenix) [ inputs.ragenix.darwinModules.default ];
      inherit age;
    };
    homeManager = {
      imports = lib.optionals (inputs ? ragenix) [ inputs.ragenix.homeManagerModules.default ];
      inherit age;
    };
  };
}
