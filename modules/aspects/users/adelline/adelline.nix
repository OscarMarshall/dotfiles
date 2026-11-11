{ den, my, ... }: {
  den.aspects.adelline = {
    includes = [
      (den._.user-shell "fish")
      (my.fish { })
      den._.primary-user
      my.chrome
      my.discord
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
      ];

      programs = {
        direnv.enable = true;
        git.enable = true;
      };
    };

    # The `user` class (users.users.adelline) rather than `nixos`, which no longer leaves a user
    # aspect for its hosts (den#694).
    user = {
      description = "Adelline Marshall";
      hashedPassword = "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
    };
  };
}
