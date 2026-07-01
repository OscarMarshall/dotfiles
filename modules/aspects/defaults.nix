{
  den,
  lib,
  my,
  self,
  ...
}:
let
  inherit (den.lib.policy) pipe;
  exposeSubstituters = pipe.from "substituters" [ pipe.expose ];
  hmPlatforms =
    { aspect-chain, ... }:
    den._.forward {
      each = [
        "Linux"
        "Darwin"
        "Aarch64"
        "64bit"
      ];
      fromClass = platform: "hm${platform}";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
      guard = { pkgs, ... }: platform: lib.mkIf pkgs.stdenv."is${platform}";
      adaptArgs = { config, ... }: { osConfig = config; };
    };
  secrets =
    {
      aspect-chain,
      home ? null,
      ...
    }:
    den._.forward {
      each = [
        "nixos"
        "darwin"
        "homeManager"
      ];
      fromClass = _: "secrets";
      intoClass = lib.id;
      intoPath = _: [
        "age"
        "secrets"
      ];
      fromAspect = _: lib.head aspect-chain;
      fromCtx = _: lib.optionalAttrs (home != null) { inherit home; };
      adaptArgs = { config, ... }: {
        inherit config;
        inherit (config.age) secrets;
      };
    };
  nixosSecrets =
    { aspect-chain, ... }:
    den._.forward {
      each = [ "nixos" ];
      fromClass = _: "nixosSecrets";
      intoClass = lib.id;
      intoPath = _: [
        "age"
        "secrets"
      ];
      fromAspect = _: lib.head aspect-chain;
      adaptArgs = { config, ... }: {
        inherit config;
        inherit (config.age) secrets;
      };
    };
in
{
  den = {
    default.includes = [
      hmPlatforms

      den.batteries.define-user
      den.batteries.hostname

      my.secrets
      my.stylix
    ];

    quirks.substituters = {
      description = ''
        Binary cache substituter declarations. Each value should be an
        attrset (or list of attrsets) of the form:
          { substituter = "https://..."; publicKey = "<name>:<key>"; }
        Collected values populate nix.settings.extra-substituters /
        extra-trusted-public-keys and flake.nixConfig for bootstrap.
      '';
    };

    schema = {
      flake.includes = [
        my.nix
        exposeSubstituters
      ];
      flake-system.includes = [ exposeSubstituters ];
      home.includes = [
        secrets
        my.nix
        my.starship
        exposeSubstituters
      ];
      host = {
        includes = [
          nixosSecrets
          secrets
          my.fonts
          my.nix
          exposeSubstituters
        ];

        os.system.configurationRevision = self.rev or self.dirtyRev or null;
      };
      user = {
        includes = [ my.starship ];

        classes = lib.mkDefault [ "homeManager" ];
      };
    };
  };
}
