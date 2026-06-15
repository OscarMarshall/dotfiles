{ lib, ... }:
let
  nixConfig =
    { config, pkgs, ... }:
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
          extra-substituters = [
            "https://nix-community.cachix.org"
            "https://oscarmarshall.cachix.org"
          ];
          extra-trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "oscarmarshall.cachix.org-1:Fa13vGeBXoJ7jWpvnalg/PCRTtvCpyuHUFL5jQXt/9w="
          ];
        };
      };
    };
in
{
  my.nix = {
    secrets =
      { secrets, ... }:
      {
        github-access-token = {
          rekeyFile = ../../../secrets/github-access-token.age;
          intermediary = true;
        };

        nix-access-tokens.generator = {
          dependencies = { inherit (secrets) github-access-token; };
          script =
            { decrypt, deps, ... }:
            ''
              printf 'access-tokens = github.com=%s\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.github-access-token.file}
              )"
            '';
        };
      };

    homeManager = nixConfig;

    os =
      { config, pkgs, ... }:
      lib.mkMerge [
        (nixConfig { inherit config pkgs; })
        { nix.optimise.automatic = true; }
      ];
  };
}
