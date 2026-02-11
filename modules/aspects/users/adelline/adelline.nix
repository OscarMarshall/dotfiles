{ den, oscarmarshall, ... }:
let
  name = "Adelline Marshall";
in
{
  den.aspects.adelline = {
    includes = with oscarmarshall; [
      den._.primary-user
      (den._.user-shell "fish")
      # (den._.unfree [ "google-chrome" ])
      discord
      ghostty
      steam
      zen-browser
      (
        { user, ... }:
        let
          shared = {
            description = name;
          };
        in
        {
          darwin.users.users.${user.userName} = shared;

          nixos.users.users.${user.userName} = shared // {
            hashedPassword = "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
          };
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
