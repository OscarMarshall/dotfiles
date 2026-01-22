{
  den,
  lib,
  oscarmarshall,
  ...
}:
let
  graphicalPackages = den.lib.parametric.atLeast {
    includes = [
      (
        { host, ... }:
        {
          homeManager =
            { pkgs, ... }:
            {
              home.packages =
                with pkgs;
                lib.optionals (host.config.services.displayManager.enable || host.class == "darwin") [
                  ghostty
                  inkscape
                  prismlauncher
                ];
            };
        }
      )
    ];
  };
in
{
  den.aspects.oscar =
    { user, ... }:
    {
      includes =
        with oscarmarshall;
        [
          den._.primary-user
          (den._.user-shell "fish")
          emacs
          graphicalPackages
          zen-browser
          (
            { host, ... }:
            {
              homeManager.home.packages = with pkgs; lib.optionals (host.class == "darwin") [ pinentry_mac ];
            }
          )
        ]
        ++ lib.optionals (user.userName == "omarshal") [
          { homeManager.programs.git.settings.user.email = "omarshal@meraki.com"; }
        ];

      nixos.users.users.oscar = {
        hashedPassword = "$y$j9T$rqKfWUlPbBLAGwIXUhAW61$LaP13MwCfvgtNlxZ/77.Pcu.tLapKf8CmepJ.GudcT4";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
        ];
      };

      homeManager =
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            fd
            gnupg
            ripgrep
            rsync

            pinentry-all
          ];

          programs = {
            direnv.enable = true;
            fzf.enable = true;
            git = {
              enable = true;
              settings = {
                init.defaultBranch = "main";
                pull.rebase = true;
                push.autoSetupRemote = true;
                user = {
                  name = "Oscar Marshall";
                  email = "oscar.lim.marshall@gmail.com";
                };
              };
            };
            starship.enable = true;
          };
        };
    };
}
