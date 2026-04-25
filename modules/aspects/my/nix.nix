{
  my.nix.os =
    { pkgs, ... }:
    {
      nix = {
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };
        optimise.automatic = true;
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
}
