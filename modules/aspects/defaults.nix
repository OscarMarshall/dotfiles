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
      adaptArgs = { config, ... }: { osConfig = config; };
      each = [
        "Linux"
        "Darwin"
        "Aarch64"
        "64bit"
      ];
      fromAspect = _: lib.head aspect-chain;
      fromClass = platform: "hm${platform}";
      guard = { pkgs, ... }: platform: lib.mkIf pkgs.stdenv."is${platform}";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
    };
  secrets =
    {
      aspect-chain,
      home ? null,
      ...
    }:
    den._.forward {
      adaptArgs = { config, ... }: {
        inherit config;
        inherit (config.age) secrets;
      };
      each = [
        "nixos"
        "darwin"
        "homeManager"
      ];
      fromAspect = _: lib.head aspect-chain;
      fromClass = _: "secrets";
      fromCtx = _: lib.optionalAttrs (home != null) { inherit home; };
      intoClass = lib.id;
      intoPath = _: [
        "age"
        "secrets"
      ];
    };
  nixosSecrets =
    { aspect-chain, ... }:
    den._.forward {
      adaptArgs = { config, ... }: {
        inherit config;
        inherit (config.age) secrets;
      };
      each = [ "nixos" ];
      fromAspect = _: lib.head aspect-chain;
      fromClass = _: "nixosSecrets";
      intoClass = lib.id;
      intoPath = _: [
        "age"
        "secrets"
      ];
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

    schema = {
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
        classes = lib.mkDefault [ "homeManager" ];
        includes = [ my.starship ];
      };
    };
  };
}
