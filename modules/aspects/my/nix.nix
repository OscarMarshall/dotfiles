{ lib, config, ... }:
let
  flakeFileNixConfig = config.flake-file.nixConfig;
  mkNixConfig = { config, pkgs }: {
    nix = {
      extraOptions = ''
        !include ${config.age.secrets.nix-access-tokens.path}
      '';
      package = pkgs.lixPackageSets.stable.lix;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      }
      // flakeFileNixConfig;
    };
  };
in
{
  flake-file.nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://oscarmarshall.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "oscarmarshall.cachix.org-1:Fa13vGeBXoJ7jWpvnalg/PCRTtvCpyuHUFL5jQXt/9w="
    ];
  };
  flake.nixConfig = flakeFileNixConfig;

  my.nix = {
    secrets = { secrets, ... }: {
      nix-github-access-token = {
        rekeyFile = ../../../secrets/nix-github-access-token.age;
        # World-readable, same as nix-access-tokens below (which already
        # exposes this same token in the clear): lets other consumers (e.g.
        # Starship) read the bare token without nix.conf's `access-tokens =
        # github.com=` wrapper.
        mode = "0444";
      };

      nix-access-tokens = {
        # World-readable: nix fetches via the client process, not the daemon,
        # so all users need to read this for authenticated GitHub API access.
        mode = "0444";
        generator = {
          dependencies = { inherit (secrets) nix-github-access-token; };
          script = { decrypt, deps, ... }: ''
            printf 'access-tokens = github.com=%s\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.nix-github-access-token.file}
            )"
          '';
        };
      };
    };

    homeManager = { config, pkgs, ... }: mkNixConfig { inherit config pkgs; };

    os =
      { config, pkgs, ... }:
      lib.mkMerge [
        (mkNixConfig { inherit config pkgs; })
        {
          nix.gc = {
            automatic = true;
            options = "--delete-older-than 7d";
          };
          nix.optimise.automatic = true;
        }
      ];
  };
}
