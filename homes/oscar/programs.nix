{pkgs, ...}: {
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
    home-manager.enable = true;
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
      envExtra = ''
        if [ -f "$HOME/.iterm2_shell_integration.zsh" ]; then
          source "$HOME/.iterm2_shell_integration.zsh"
        fi
      '';
    };
  };
}
