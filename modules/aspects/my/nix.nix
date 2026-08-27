{ config, lib, ... }:
let
  flakeFileNixConfig = config.flake-file.nixConfig;
  mkNixConfig = { config, pkgs }: {
    nix = {
      package = pkgs.lixPackageSets.stable.lix;

      extraOptions = ''
        !include ${config.age.secrets.nix-access-tokens.path}
      '';

      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          # Umbriel's flake (my.umbriel) uses `inputs.self.submodules`, which Lix gates behind this.
          "flake-self-attrs"
        ];
      }
      // flakeFileNixConfig;
    };
  };
in
{
  flake-file.nixConfig = {
    # Umbriel's flake (an input via my.umbriel) sets `inputs.self.submodules = true` to pull its
    # patched SceneFX fork. Lix gates that attr behind this experimental feature, so evaluating -
    # and therefore locking - the input fails without it. Deployed systems also pick this up because
    # `flakeFileNixConfig` is merged into `nix.settings` below.
    extra-experimental-features = [ "flake-self-attrs" ];

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
    homeManager = { config, pkgs, ... }: mkNixConfig { inherit config pkgs; };

    os =
      { config, pkgs, ... }:
      lib.mkMerge [
        (mkNixConfig { inherit config pkgs; })
        {
          nix = {
            gc = {
              options = "--delete-older-than 7d";
              automatic = true;
            };

            optimise.automatic = true;
          };
        }
      ];

    secrets = { secrets, ... }: {
      nix-access-tokens = {
        generator = {
          dependencies = { inherit (secrets) nix-github-access-token; };

          script = { decrypt, deps, ... }: ''
            printf 'access-tokens = github.com=%s\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.nix-github-access-token.file}
            )"
          '';
        };

        # World-readable: nix fetches via the client process, not the daemon,
        # so all users need to read this for authenticated GitHub API access.
        mode = "0444";
      };

      nix-github-access-token = {
        # World-readable, same as nix-access-tokens below (which already
        # exposes this same token in the clear): lets other consumers (e.g.
        # Starship) read the bare token without nix.conf's `access-tokens =
        # github.com=` wrapper.
        mode = "0444";
        rekeyFile = ../../../secrets/nix-github-access-token.age;
      };
    };
  };
}
