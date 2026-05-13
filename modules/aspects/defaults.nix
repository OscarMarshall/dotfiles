{
  config,
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
      adaptArgs =
        { config, ... }:
        {
          osConfig = config;
        };
    };
  secrets =
    { aspect-chain, ... }:
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
      adaptArgs =
        { config, ... }:
        {
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
      adaptArgs =
        { config, ... }:
        {
          inherit config;
          inherit (config.age) secrets;
        };
    };
in
{
  den = {
    defaults = {
      includes = [
        my.fonts
        my.nix
        my.secrets
        my.stylix

        # Automatically set hostname.
        den._.hostname

        # Disable booting when running on CI on all NixOS hosts.
        (if config ? _module.args.CI then my.ci-no-boot else { })

        # ${user}.provides.${host} and ${host}.provides.${user}
        den._.mutual-provider

        my.starship

        # Automatically create the user on host.
        den._.define-user
      ];

      os.system.configurationRevision = self.rev or self.dirtyRev or null;

      darwin.programs.man.generateCaches = false;
    };

    schema = {
      host = {
        includes = [
          secrets
          nixosSecrets
        ];

        options = {
          graphical = lib.mkEnableOption "Whether the host should include graphical packages";
          work = lib.mkEnableOption "Whether the host is a work machine";
        };

        config = {
          graphical = lib.mkDefault false;
          work = lib.mkDefault false;
        };
      };
  
      user = {
        includes = [ hmPlatforms ];
  
        classes = [ "homeManager" ];
      };
    };
  };
}
