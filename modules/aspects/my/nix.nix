{ lib, ... }:
let
  substituters = [
    {
      substituter = "https://nix-community.cachix.org";
      publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    }
    {
      substituter = "https://oscarmarshall.cachix.org";
      publicKey = "oscarmarshall.cachix.org-1:Fa13vGeBXoJ7jWpvnalg/PCRTtvCpyuHUFL5jQXt/9w=";
    }
  ];
  mkNixConfig =
    {
      substituters,
      config,
      pkgs,
    }:
    {
      nix = {
        extraOptions = ''
          !include ${config.age.secrets.nix-access-tokens.path}
        '';
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };
        package = pkgs.lixPackageSets.stable.lix;
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          extra-substituters = map (s: s.substituter) substituters;
          extra-trusted-public-keys = map (s: s.publicKey) substituters;
        };
      };
    };
in
{
  flake-file.nixConfig = {
    extra-substituters = map (s: s.substituter) substituters;
    extra-trusted-public-keys = map (s: s.publicKey) substituters;
  };

  my.nix = {
    inherit substituters;

    secrets = { secrets, ... }: {
      nix-github-access-token = {
        rekeyFile = ../../../secrets/nix-github-access-token.age;
        intermediary = true;
      };

      # World-readable: nix fetches via the client process, not the daemon,
      # so all users need to read this for authenticated GitHub API access.
      nix-access-tokens.mode = "0444";
      nix-access-tokens.generator = {
        dependencies = { inherit (secrets) nix-github-access-token; };
        script = { decrypt, deps, ... }: ''
          printf 'access-tokens = github.com=%s\n' "$(
            ${decrypt} ${lib.escapeShellArg deps.nix-github-access-token.file}
          )"
        '';
      };
    };

    homeManager =
      {
        substituters,
        config,
        pkgs,
        ...
      }:
      mkNixConfig { inherit substituters config pkgs; };

    os =
      {
        substituters,
        config,
        pkgs,
        ...
      }:
      lib.mkMerge [
        (mkNixConfig { inherit substituters config pkgs; })
        { nix.optimise.automatic = true; }
      ];

    flake = { substituters, ... }: {
      flake.nixConfig = {
        extra-substituters = lib.unique (map (s: s.substituter) substituters);
        extra-trusted-public-keys = lib.unique (map (s: s.publicKey) substituters);
      };
    };
  };
}
