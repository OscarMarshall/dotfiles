{
  den,
  lib,
  my,
  ...
}:
let
  name = "Oscar Marshall";
  scopeFromArgs =
    {
      host ? null,
      home ? null,
      ...
    }@args:
    if host != null then
      host
    else if home != null then
      home
    else
      args;
  userAspect =
    { user, ... }:
    {
      nixos =
        { config, ... }:
        {
          users.users.${user.userName} = {
            openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt95coA4j19+fPxpOLRfIFb7AvAXdSmf1MyOPibmhe/" ];
            hashedPasswordFile = toString config.age.secrets.oscar-hashed-password.file;
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
      userAspect
      (
        args:
        let
          scope = scopeFromArgs args;
        in
        {
          includes =
            with my;
            lib.optionals (scope.graphical or false) [
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
                lib.optionals (scope.graphical or false) [
                  inkscape
                  mkvtoolnix
                  prismlauncher
                ];
            };
        }
      )
    ];

    provides."dev203.meraki.com" = {
      includes = builtins.attrValues den.aspects.oscar.provides.work.provides;

      homeManager =
        { pkgs, ... }:
        {
          home = {
            packages = [ pkgs.codex ];
            sessionVariables.PATH = "$HOME/.nix-profile/bin:$PATH";
            stateVersion = "26.05";
          };
        };
    };

    user.description = name;

    nixosSecrets =
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
