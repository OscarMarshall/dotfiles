{ den, lib, ... }:
let
  graphicalPackages = den.lib.parametric.atLeast {
    includes = [
      (den._.unfree [ "google-chrome" ])
      (
        { host, ... }:
        {
          includes = [ ];
          homeManager =
            { pkgs, ... }:
            {
              home.packages =
                with pkgs;
                lib.optionals host.config.services.displayManager.enable [
                  google-chrome
                  ghostty
                  krita
                  prismlauncher
                  rnote
                ];
            };
        }
      )
    ];
  };
in
{
  den.aspects.adelline = {
    includes = [
      den._.primary-user
      (den._.user-shell "fish")
      graphicalPackages
    ];

    nixos.users.users.adelline.hashedPassword = "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";

    homeManager =
      { ... }:
      {

      };
  };
}
