{ den, my, ... }:
{
  den.aspects.adelline = {
    user.description = "Adelline Marshall";

    includes = with my; [
      den._.primary-user
      (den._.user-shell "fish")
      (den._.unfree [ "google-chrome" ])
      discord
      ghostty
      steam
      zen-browser
      (
        { user, ... }:
        {
          nixos.users.users.${user.userName}.hashedPassword =
            "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
        }
      )
    ];

    homeManager =
      { pkgs, ... }:
      {
        dconf = {
          enable = true;
          settings = {
            "org/gnome/desktop/screensaver".lock-enabled = false;
            "org/gnome/settings-daemon/plugins/power".power-button-action = "nothing";
          };
        };

        home.packages = with pkgs; [
          google-chrome
          inkscape
          krita
          prismlauncher
          rnote
        ];

        programs = {
          direnv.enable = true;
          fish.enable = true;
          git.enable = true;
          starship.enable = true;
        };
      };
  };
}
