{
  den,
  lib,
  my,
  ...
}:
let
  name = "Oscar Marshall";
  graphicalAspect =
    { host, ... }:
    {
      includes =
        with my;
        lib.optionals (host.graphical or false) [
          (catppuccin { })
          discord
          doc-browser
          ghostty
          orca-slicer
          prusa-slicer
          steam
          zen-browser
        ];
      homeManager =
        { pkgs, ... }:
        {
          home.packages =
            with pkgs;
            lib.optionals (host.graphical or false) [
              inkscape
              prismlauncher
            ];
        };
    };
  userAspect =
    { user, ... }:
    {
      nixos =
        { config, ... }:
        {
          users.users.${user.name} = {
            openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt95coA4j19+fPxpOLRfIFb7AvAXdSmf1MyOPibmhe/" ];
            hashedPasswordFile = config.age.secrets.oscar-hashed-password.file;
          };
        };
    };
in
{
  den.aspects.oscar = {
    includes = builtins.attrValues den.aspects.oscar.provides ++ [
      den._.primary-user
      (den._.user-shell "fish")
      my.bat
      my.direnv
      my.emacs
      (my.git {
        inherit name;
        email = "3111765+OscarMarshall@users.noreply.github.com";
      })
      my.gpg
      my.nh
      my.nix-index
      my.proton-pass
      my.ssh-client
      graphicalAspect
      userAspect
    ];

    secrets =
      { secrets, ... }:
      {
        oscar-password = {
          rekeyFile = ../../../../secrets/oscar-password.age;
          intermediary = true;
        };

        oscar-hashed-password.generator = {
          dependencies = { inherit (secrets) oscar-password; };
          script =
            {
              decrypt,
              deps,
              lib,
              pkgs,
              ...
            }:
            ''
              ${pkgs.mkpasswd}/bin/mkpasswd "$(${decrypt} ${lib.escapeShellArg deps.oscar-password.file})"
            '';
        };
      };

    user.description = name;

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
