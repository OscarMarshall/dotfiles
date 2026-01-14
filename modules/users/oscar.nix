{inputs, ...}: let
  username = "oscar";
in {
  flake.modules.nixos."${username}" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home-manager.users."${username}" = {
      imports = [
        inputs.self.modules.homeManager."${username}"
      ];
    };

    users.users."${username}" = {
      description = "Oscar Marshall";
      isNormalUser = true;
      extraGroups = ["wheel"];
      hashedPassword = "$y$j9T$rqKfWUlPbBLAGwIXUhAW61$LaP13MwCfvgtNlxZ/77.Pcu.tLapKf8CmepJ.GudcT4";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
      ];
      packages = [
        pkgs.rcon-cli
      ];
    };
  };

  flake.modules.homeManager."${username}" = {
    pkgs,
    lib,
    osConfig,
    ...
  }: {
    home = {
      username = "${username}";

      sessionPath = [
        "$HOME/.config/emacs/bin"
      ];
      sessionVariables = {
        EDITOR = "emacs";
      };
      shell.enableZshIntegration = true;
      packages =
        [
          pkgs.emacs
          pkgs.pinentry-tty
        ]
        ++ lib.optionals (osConfig.networking.hostName == "melaan") [
          pkgs.prismlauncher
        ];
    };

    programs = {
      direnv.enable = true;
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
      home-manager.enable = true; # Let Home Manager install and manage itself.
      starship.enable = true;
      zsh = {
        enable = true;
        antidote = {
          enable = true;
          plugins = [
            # Completions
            "mattmc3/ez-compinit"
            "zsh-users/zsh-completions kind:fpath path:src"

            "belak/zsh-utils path:editor"
            "belak/zsh-utils path:history"
            "belak/zsh-utils path:utility"

            "rupa/z"
            "zsh-users/zsh-autosuggestions"
            "zdharma-continuum/fast-syntax-highlighting kind:defer"

            "joshskidmore/zsh-fzf-history-search"
          ];
        };
        historySubstringSearch = {
          enable = true;
          searchDownKey = ["^[[B" "^[OB"];
          searchUpKey = ["^[[A" "^[OA"];
        };
        initExtra = ''
          # Source iTerm2 shell integration if it exists
          [ -f ~/.iterm2_shell_integration.zsh ] && source ~/.iterm2_shell_integration.zsh
        '';
      };
    };

    home.stateVersion = "25.05";
  };
}
