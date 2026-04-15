{ den, my, ... }:
let
  name = "Oscar Marshall";
in
{
  den.aspects.oscar = {
    user.description = name;

    includes =
      with my;
      builtins.attrValues den.aspects.oscar.provides
      ++ [
        den._.primary-user
        (den._.user-shell "fish")
        emacs
        (git {
          inherit name;
          email = "3111765+OscarMarshall@users.noreply.github.com";
        })
        gpg
        ssh-client
        (
          { user, ... }:
          {
            nixos.users.users.${user.userName} = {
              hashedPassword = "$y$j9T$rqKfWUlPbBLAGwIXUhAW61$LaP13MwCfvgtNlxZ/77.Pcu.tLapKf8CmepJ.GudcT4";
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
              ];
            };
          }
        )
        (host-flag "graphical" {
          includes = [
            (catppuccin { })
            discord
            docsets
            ghostty
            orca-slicer
            prusa-slicer
            steam
            zen-browser
          ];

          homeManager =
            { pkgs, ... }:
            {
              home.packages = with pkgs; [
                inkscape
                prismlauncher
              ];
            };
        })
      ];

    darwin.homebrew.casks = [
      "arc"
      "domzilla-caffeine"
      "proton-mail"
    ];

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
        };

        stylix.fonts = {
          monospace = {
            package = pkgs.nerd-fonts.fira-code;
            name = "FiraCode Nerd Font Mono";
          };
          sansSerif = {
            package = pkgs.fira;
            name = "Fira Sans";
          };
        };
      };
  };
}
