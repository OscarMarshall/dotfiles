{
  den,
  lib,
  my,
  self,
  ...
}:
let
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
      description = "Binary cache substituter declarations";
    };

    schema = {
      flake.includes = [ my.nix ];
      home.includes = [
        secrets
        my.nix
        my.starship
      ];
      host = {
        includes = [
          nixosSecrets
          secrets
          my.fonts
          my.nix
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
