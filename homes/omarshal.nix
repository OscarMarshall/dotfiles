{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.zen-browser.homeModules.twilight];

  home = {
    # Home Manager needs a bit of information about you and the
    # paths it should manage.
    username = "omarshal";

    sessionPath = [
      "$HOME/.config/emacs/bin"
    ];
    sessionVariables = {
      EDITOR = "emacs";
      ITERM2_SQUELCH_MARK = 1;
    };
    shell.enableZshIntegration = true;
  };

  programs = {
    direnv.enable = true;
    home-manager.enable = true; # Let Home Manager install and manage itself.
    java.enable = true;
    rbenv.enable = true;
    starship.enable = true;
    # zen-browser = {
    #   enable = true;
    #   policies = let
    #     locked = value: {
    #       Value = value;
    #       Status = "locked";
    #     };
    #   in {
    #     AutofillAddressEnabled = true;
    #     AutofillCreditCardEnabled = false;
    #     DisableAppUpdate = true;
    #     DisableFeedbackCommands = true;
    #     DisableFirefoxStudies = true;
    #     DisablePocket = true; # save webs for later reading
    #     DisableTelemetry = true;
    #     DontCheckDefaultBrowser = true;
    #     NoDefaultBookmarks = true;
    #     OfferToSaveLogins = false;
    #     EnableTrackingProtection = {
    #       Value = true;
    #       Locked = true;
    #       Cryptomining = true;
    #       Fingerprinting = true;
    #     };
    #     ExtensionSettings = {
    #     };
    #     Preferences = builtins.mapAttrs (_: locked) {
    #       "media.videocontrols.picture-in-picture.video-toggle.enabled" = true;
    #     };
    #   };
    # };
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
        source ~/.iterm2_shell_integration.zsh
        eval "$(/opt/homebrew/bin/brew shellenv)"
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
