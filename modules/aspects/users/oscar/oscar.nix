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
      gpg
      (host-flag "graphical" [
        discord
        ghostty
        prusa-slicer
        steam
        zen-browser
        {
          homeManager =
            { pkgs, ... }:
            {
              home.packages = with pkgs; [
                inkscape
                prismlauncher
                zeal
              ];
            };
        }
      ])
      (host-flag "work" [ { homeManager.programs.git.settings.user.email = lib.mkForce "omarshal@meraki.com"; } ])
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
