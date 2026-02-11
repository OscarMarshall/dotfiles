{
  den,
  lib,
  oscarmarshall,
  ...
}:
let
  name = "Oscar Marshall";
in
{
  den.aspects.oscar = {
    includes = with oscarmarshall; [
      den._.primary-user
      (den._.user-shell "fish")
      emacs
      (git {
        inherit name;
        email = "3111765+OscarMarshall@users.noreply.github.com";
      })
      gpg
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
            hashedPassword = "$y$j9T$rqKfWUlPbBLAGwIXUhAW61$LaP13MwCfvgtNlxZ/77.Pcu.tLapKf8CmepJ.GudcT4";
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
            ];
          };
        }
      )
      (host-flag "graphical" {
        includes = [
          discord
          ghostty
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
              zeal
            ];
          };
      })
      (host-flag "work" { homeManager.programs.git.settings.user.email = lib.mkForce "omarshal@meraki.com"; })
    ];

    darwin.homebrew.casks = [
      "arc"
      "dash"
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
          starship.enable = true;
        };
      };
  };
}
