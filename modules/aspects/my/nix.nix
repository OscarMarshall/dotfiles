let
  config =
    { pkgs, ... }:
    {
      nix = {
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
          substituters = [ "https://nix-community.cachix.org" ];
          trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
        };
      };
    };
in
{
  my.nix = {
    darwin = config;
    nixos = config;
  };
}
