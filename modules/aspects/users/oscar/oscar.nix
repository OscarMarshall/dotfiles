{
  den,
  lib,
  my,
  ...
}:
let
  name = "Oscar Marshall";
  contextAttrs =
    context:
    if (context ? host) && context.host != null then
      context.host
    else if (context ? home) && context.home != null then
      context.home
    else
      context;
  contextFlag = context: flag: (contextAttrs context).${flag} or false;
  graphicalAspect = context: {
    includes =
      with my;
      lib.optionals (contextFlag context "graphical") [
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
          lib.optionals (contextFlag context "graphical") [
            inkscape
            mkvtoolnix
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
      graphicalAspect
      userAspect
    ];

    provides."dev203.meraki.com" =
      context:
      lib.mkIf
        (
          (context.hostName or null) == "dev203.meraki.com"
          || ((context ? home) && context.home != null && context.home.hostName == "dev203.meraki.com")
        )
        {
          homeManager.home = {
            sessionVariables.PATH = "$HOME/.nix-profile/bin:$PATH";
            stateVersion = "26.05";
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
      args@{ pkgs, ... }:
      {
        home = {
          packages = with pkgs; [
            fd
            gnupg
            ripgrep
            rsync
          ];
          sessionVariables.PATH = lib.mkDefault "$HOME/.nix-profile/bin:$PATH";
          stateVersion = lib.mkDefault "26.05";
        };

        programs = {
          fish.enable = true;
          fzf.enable = true;
        };
      }
      // lib.optionalAttrs (args ? osConfig) {
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
