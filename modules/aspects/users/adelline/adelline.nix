{
  den,
  lib,
  oscarmarshall,
  ...
}:
{
  den.aspects.adelline = {
    includes = with oscarmarshall; [
      den._.primary-user
      (den._.user-shell "fish")
      ghostty
      zen-browser
      (
        { HM-OS-USER }:
        {
          includes = [
            (den._.unfree [ "google-chrome" ])

          ];

          homeManager =
            { pkgs, ... }:
            {
              home.packages =
                with pkgs;
                lib.optionals HM-OS-USER.user.graphical [
                  google-chrome
                  inkscape
                  krita
                  prismlauncher
                  rnote
                ];
            };
        }
      )
    ];

    homeManager = {
      home.shell.enableFishIntegration = true;

      programs = {
        direnv.enable = true;
        fish.enable = true;
        git.enable = true;
        starship.enable = true;
      };
    };
  };
}
