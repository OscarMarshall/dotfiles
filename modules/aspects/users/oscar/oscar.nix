{
  den,
  lib,
  my,
  ...
}:
let
  name = "Oscar Marshall";
  userAspect = { user, ... }: {
    nixos = { config, ... }: {
      users.users.${user.userName} = {
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt95coA4j19+fPxpOLRfIFb7AvAXdSmf1MyOPibmhe/" ];
        hashedPasswordFile = toString config.age.secrets.oscar-hashed-password.file;
      };
    };
  };
in
{
  den.aspects.oscar =
    {
      host ? null,
      home ? null,
      ...
    }:
    let
      scope =
        if host != null then
          host
        else if home != null then
          home
        else
          { };
    in
    {
      includes = [
        den.aspects.oscar.provides.work
        den._.primary-user
        (den._.user-shell "fish")
        my.bat
        my.claude
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
        (my.logseq { cli-only = !(scope.graphical or false); })
        userAspect
      ]
      ++ lib.optionals (scope.graphical or false) (
        with my;
        [
          (catppuccin { })
          discord
          doc-browser
          ghostty
          orca-slicer
          programmer-dvorak
          prusa-slicer
          steam
          zen-browser
        ]
      );

      provides."dev203.meraki.com" = {
        homeManager = {
          home = {
            sessionVariables.PATH = "$HOME/.nix-profile/bin:$PATH";
            stateVersion = "26.05";
          };
        };

        # See the comment on provides.oscar in OMARSHAL-M-2FD2.nix for why these sentinels are needed:
        # this home entity's re-walked spawn scope doesn't re-run the user aspect's own includes, so
        # hmLinux is absent at compile time without this and the forward falls through to resolveSourceFallback.
        hmLinux = { };
        hmDarwin = { };
        hmAarch64 = { };
        hm64bit = { };
      };

      user.description = name;

      nixosSecrets = { secrets, ... }: {
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

      homeManager = { pkgs, ... }: {
        # age uses this key when rekeying home-manager-level secrets. At
        # activation time, age decrypts via the Proton Pass SSH agent
        # (SSH_AUTH_SOCK) without needing a private key file on disk.
        age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt95coA4j19+fPxpOLRfIFb7AvAXdSmf1MyOPibmhe/";

        home.packages =
          with pkgs;
          [
            fd
            gnupg
            ripgrep
            rsync
          ]
          ++ lib.optionals (scope.graphical or false) [
            inkscape
            mkvtoolnix
            mpv
            prismlauncher
          ];

        programs = {
          fish.enable = true;
          ssh.matchBlocks."github-personal" = {
            hostname = "github.com";
            user = "git";
            identityFile = "${./id_ed25519_personal.pub}";
            identitiesOnly = true;
          };
          fzf.enable = true;
          gh = {
            enable = true;
            settings.git_protocol = "ssh";
          };
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
