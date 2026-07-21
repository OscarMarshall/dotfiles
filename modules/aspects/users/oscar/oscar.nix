{
  lib,
  den,
  my,
  ...
}:
let
  name = "Oscar Marshall";
  userAspect = { user, ... }: {
    nixos = { config, ... }: {
      users.users.${user.userName} = {
        hashedPasswordFile = toString config.age.secrets.oscar-hashed-password.file;
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt95coA4j19+fPxpOLRfIFb7AvAXdSmf1MyOPibmhe/" ];
      };
    };

    # nixos/modules/config/nix.nix and nix-darwin's equivalent both set
    # `nix.settings.trusted-users = [ "root" ]` as a real config-level definition
    # (not just an mkOption default), and trusted-users is a listOf — definitions
    # concatenate rather than override, so root can't be dropped by adding to this list.
    os.nix.settings.trusted-users = [ user.userName ];
  };
in
{
  den.aspects.oscar =
    {
      home ? null,
      host ? null,
      ...
    }:
    let
      # `home` is checked before `host`: a standalone home named `user@undeclared-host`
      # (e.g. dev203) gets a synthetic `host = { name = ...; }` from den purely so
      # host-keyed cross-entity policies can match on `host.name` - it never carries
      # `work`/`graphical`. The real attributes always live on `home` for those.
      scope =
        if home != null then
          home
        else if host != null then
          host
        else
          { };
    in
    {
      includes = [
        (den._.user-shell "fish")
        (my.git {
          inherit name;
          email = "3111765+OscarMarshall@users.noreply.github.com";
        })
        (my.logseq { cli-only = !(scope.graphical or false); })
        den._.primary-user
        den.aspects.oscar.provides.work
        my.bat
        my.claude
        my.direnv
        my.emacs
        my.fish
        my.gpg
        my.nh
        my.nix-index
        my.proton-pass
        my.ssh-client
        userAspect
      ]
      ++ lib.optionals (scope.graphical or false) [
        (my.catppuccin { })
        den.aspects.oscar.provides.zen-browser
        my.discord
        my.doc-browser
        my.ghostty
        my.mkvtoolnix
        my.orca-slicer
        my.programmer-dvorak
        my.prusa-slicer
        my.steam
      ];

      darwin = {
        homebrew.casks = [
          "arc"
          "domzilla-caffeine"
          "proton-mail"
        ];

        users = {
          knownUsers = [ "oscar" ];
          users.oscar.uid = 501;
        };
      };

      homeManager = { pkgs, ... }: {
        # age uses this key when rekeying home-manager-level secrets. age has
        # no ssh-agent support (it only reads identity *files*, never a
        # running agent - https://github.com/FiloSottile/age/discussions/532),
        # so at activation time it decrypts via ragenix's default
        # identityPaths (~/.ssh/id_ed25519). This is a dedicated key (not the
        # Proton-Pass-agent-only "Main SSH Key" used for git/GitHub) whose
        # private half is age-encrypted at ../../../../secrets/oscar-ssh-private-key.age,
        # decryptable only via the YubiKey master identity. Run
        # `nix run .#install-ssh-key` (YubiKey required, one-time per
        # machine) to place it at ~/.ssh/id_ed25519.
        age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJP/48MuP5o4PrUkpgY/3bAB7QN6JFfX1He7M92qnO9F";

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
            mpv
            prismlauncher
          ];

        programs = {
          fzf.enable = true;

          gh = {
            enable = true;
            settings.git_protocol = "ssh";
          };

          ssh.settings."github-personal" = {
            HostName = "github.com";
            IdentitiesOnly = true;
            IdentityFile = "${./id_ed25519_personal.pub}";
            User = "git";
          };
        };

        # On work machines, the agent needs SSH keys from both the Personal and Meraki
        # vaults - pass-cli's ssh-agent only accepts a single --vault-name, so the only way
        # to cover more than one named vault is to omit the flag and let it scan all vaults.
        services.proton-pass-agent.extraArgs = lib.optionals (!(scope.work or false)) [
          "--vault-name"
          "Personal"
        ];

        stylix.fonts = {
          monospace = {
            package = pkgs.maple-mono.NF;
            name = "Maple Mono NF";
          };

          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };
        };
      };

      nixosSecrets = { secrets, ... }: {
        oscar-hashed-password.generator = {
          dependencies = { inherit (secrets) oscar-password; };

          script =
            {
              lib,
              pkgs,
              decrypt,
              deps,
              ...
            }:
            ''
              ${pkgs.mkpasswd}/bin/mkpasswd "$(${decrypt} ${lib.escapeShellArg deps.oscar-password.file})"
            '';
        };

        oscar-password = {
          intermediary = true;
          rekeyFile = ../../../../secrets/oscar-password.age;
        };

        # Consumed only by `nix run .#install-ssh-key` to bootstrap
        # `~/.ssh/id_ed25519` on a fresh machine - not generated into
        # anything or deployed as a per-host `age.secrets` entry.
        oscar-ssh-private-key = {
          intermediary = true;
          rekeyFile = ../../../../secrets/oscar-ssh-private-key.age;
        };
      };

      user.description = name;

      provides."dev203.meraki.com" = {
        hm64bit = { };
        hmAarch64 = { };
        hmDarwin = { };
        # See the comment on provides.oscar in OMARSHAL-M-T2QF.nix for why these sentinels are needed:
        # this home entity's re-walked spawn scope doesn't re-run the user aspect's own includes, so
        # hmLinux is absent at compile time without this and the forward falls through to resolveSourceFallback.
        hmLinux = { };

        homeManager.home = {
          sessionVariables.PATH = "$HOME/.nix-profile/bin:$PATH";
          stateVersion = "26.05";
        };
      };
    };

  # `nix run .#install-ssh-key` - bootstraps `~/.ssh/id_ed25519` on a fresh
  # machine from the YubiKey-only `oscar-ssh-private-key` intermediary secret
  # below, as an explicit manual step rather than home-manager activation, so
  # it never runs unattended (e.g. harmony's `system.autoUpgrade`) where no
  # YubiKey is ever present to satisfy it.
  perSystem = { pkgs, ... }: {
    packages.install-ssh-key = pkgs.writeShellApplication {
      name = "install-ssh-key";

      runtimeInputs = [
        pkgs.age
        pkgs.age-plugin-yubikey
      ];

      text = ''
        key_path="$HOME/.ssh/id_ed25519"

        if [ -e "$key_path" ] && [ "''${1:-}" != "--force" ]; then
          echo "install-ssh-key: $key_path already exists (pass --force to overwrite)" >&2
          exit 1
        fi

        mkdir -p "$HOME/.ssh"
        umask 077
        age --decrypt \
          -i ${../../../../secrets/yubikey-identity.pub} \
          -o "$key_path" \
          ${../../../../secrets/oscar-ssh-private-key.age}
        chmod 600 "$key_path"
        echo "install-ssh-key: wrote $key_path"
      '';
    };
  };
}
