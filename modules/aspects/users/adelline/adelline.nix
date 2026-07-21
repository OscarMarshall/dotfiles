{ den, my, ... }: {
  den.aspects.adelline = {
    includes = [
      (den._.user-shell "fish")
      ({ user, ... }: {
        nixos.users.users.${user.userName}.hashedPassword =
          "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
      })
      den._.primary-user
      my.chrome
      my.discord
      my.fish
      my.ghostty
      my.steam
      my.zen-browser
      my.zoom
    ];

    homeManager = { pkgs, ... }: {
      dconf.settings = {
        "org/gnome/desktop/screensaver".lock-enabled = false;
        "org/gnome/settings-daemon/plugins/power".power-button-action = "nothing";
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
        git.enable = true;
      };
    };

    user.description = "Adelline Marshall";
  };
}
