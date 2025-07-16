{ config, pkgs, ... }:

{
  home = {
    # Home Manager needs a bit of information about you and the
    # paths it should manage.
    username = "oscar";

    sessionPath = [
      "$HOME/.config/emacs/bin"
    ];
    sessionVariables = {
      EDITOR = "emacs";
    };
    shell.enableZshIntegration = true;
  };

  programs = {
    direnv.enable = true;
    fzf.enable = true;
    git = {
      enable = true;
      userName = "Oscar Marshall";
      userEmail = "oscar.lim.marshall@gmail.com";
      extraConfig.init.defaultBranch = "main";
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
        searchDownKey = [ "^[[B" "^[OB" ];
        searchUpKey = [ "^[[A" "^[OA" ];
      };
      envExtra = ''
        source ~/.iterm2_shell_integration.zsh
      '';
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
