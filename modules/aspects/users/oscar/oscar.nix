{
  den,
  lib,
  oscarmarshall,
  ...
}:
{
  den.aspects.oscar = {
    includes = with oscarmarshall; [
      den._.primary-user
      (den._.user-shell "fish")
      emacs
      ghostty
      pinentry
      zen-browser
      (
        { HM-OS-USER }:
        {
          homeManager =
            { pkgs, ... }:
            {
              home.packages =
                with pkgs;
                lib.optionals HM-OS-USER.user.graphical [
                  inkscape
                  prismlauncher
                ];
            };
        }
      )
      (
        { HM-OS-USER }:
        {
          homeManager.programs.git.settings.user.email = lib.mkIf (HM-OS-USER.user.userName == "omarshal") (
            lib.mkForce "omarshal@meraki.com"
          );
        }
      )
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
        home = {
          packages = with pkgs; [
            fd
            gnupg
            ripgrep
            rsync
          ];
          shell.enableFishIntegration = true;
        };

        programs = {
          direnv.enable = true;
          fish.enable = true;
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
