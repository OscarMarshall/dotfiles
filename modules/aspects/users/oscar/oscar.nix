{
  den,
  lib,
  my,
  ...
}:
let
  name = "Oscar Marshall";
in
{
  den.aspects.oscar =
    { host, user }:
    {
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
          nh
          nix-index
          ssh-client
        ]
        ++ lib.optionals (host.graphical or false) [
          (catppuccin { })
          discord
          doc-browser
          ghostty
          orca-slicer
          prusa-slicer
          steam
          zen-browser
        ];

      user.description = name;

      nixos = { pkgs, ... }: {
        programs.fish.enable = true;
        users.users.${user.userName} = {
          hashedPassword = "$y$j9T$rqKfWUlPbBLAGwIXUhAW61$LaP13MwCfvgtNlxZ/77.Pcu.tLapKf8CmepJ.GudcT4";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
          ];
          shell = pkgs.fish;
        };
      };

      darwin.homebrew.casks = [
        "arc"
        "domzilla-caffeine"
        "proton-mail"
      ];

      homeManager =
        { pkgs, ... }:
        {
          home = {
            packages =
              with pkgs;
              [
                fd
                gnupg
                ripgrep
                rsync
              ]
              ++ lib.optionals (host.graphical or false) [
                inkscape
                prismlauncher
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
