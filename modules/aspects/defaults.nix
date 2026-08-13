{
  lib,
  den,
  my,
  self,
  ...
}:
let
  # GUI-launched processes (e.g. an app opened from Spotlight/Dock, not a fish shell) are spawned
  # by launchd directly - they never source fish's PATH, and nix-darwin's `environment.variables`
  # only reaches shell-initialized processes too. `launchd.user.envVariables` is nix-darwin's own
  # mechanism for the launchd-spawned case: it runs `launchctl setenv` on every activation (see
  # nix-darwin's modules/system/launchd.nix), which is picked up immediately, no relogin needed.
  # No-ops on NixOS hosts - `darwin`-class content there is never merged into the option tree.
  guiPath = {
    darwin = { config, ... }: {
      launchd.user.envVariables.PATH = "${config.system.primaryUserHome}/.nix-profile/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
  };
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
in
{
  den = {
    default.includes = [
      den.batteries.define-user
      den.batteries.hostname
      hmPlatforms
      my.secrets
      my.stylix
    ];

    schema = {
      home.includes = [
        my.nix
        my.starship
        secrets
      ];

      host = {
        includes = [
          guiPath
          my.fonts
          my.nix
          nixosSecrets
          secrets
        ];

        # The one domain every aspect that needs a public hostname (dns.nix, nginx.nix,
        # authentik.nix, etc.) builds off of via `host.domain` - a schema default rather than a
        # per-host attribute since every host shares it today. `mkDefault` so a host could still
        # override it if that ever changes.
        domain = lib.mkDefault "silverlight-nex.us";
        os.system.configurationRevision = self.rev or self.dirtyRev or null;
      };

      user = {
        includes = [ my.starship ];
        classes = lib.mkDefault [ "homeManager" ];
      };
    };
  };
}
