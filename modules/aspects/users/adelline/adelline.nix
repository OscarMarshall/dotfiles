{ den, my, ... }: {
  den.aspects.adelline = {
    includes = [
      den._.primary-user
      (den._.user-shell "fish")
      my.discord
      my.chrome
      my.ghostty
      my.steam
      my.zoom
      my.zen-browser
      ({ user, ... }: {
        nixos.users.users.${user.userName}.hashedPassword =
          "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
      })
    ];

    user.description = "Adelline Marshall";

    homeManager = { pkgs, ... }: {
      dconf = {
        enable = true;
        settings = {
          "org/gnome/desktop/screensaver".lock-enabled = false;
          "org/gnome/settings-daemon/plugins/power".power-button-action = "nothing";
        };
      };

      home.packages = with pkgs; [
        inkscape
        krita
        prismlauncher
        rnote
        stirling-pdf-desktop
      ];

      programs = {
        direnv.enable = true;
        fish.enable = true;
        git.enable = true;
      };
    };
  };
}
