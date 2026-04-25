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
in
{
  den = {
    schema.user.classes = [ "homeManager" ];

    ctx = {
      host = {
        includes = with my; [
          fonts
          nix
          stylix

          # Automatically set hostname.
          den._.hostname

          # Disable booting when running on CI on all NixOS hosts.
          (if config ? _module.args.CI then my.ci-no-boot else { })
        ];

        os.system.configurationRevision = self.rev or self.dirtyRev or null;
      };

      user.includes = with my; [
        hmPlatforms

        # ${user}.provides.${host} and ${host}.provides.${user}
        den._.mutual-provider

        starship

        # Automatically create the user on host.
        den._.define-user
      ];
    };
  };
}
