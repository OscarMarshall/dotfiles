{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}: let
  # Custom Emacs with darwin-specific patches
  darwinEmacs = lib.mkIf pkgs.stdenv.isDarwin (
    (pkgs.emacs.override {withNativeCompilation = true;}).overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ [
          # Fix OS window role (needed for window managers like yabai)
          (pkgs.fetchpatch {
            url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-28/fix-window-role.patch";
            sha256 = "sha256-+z/KfsBm1lvZTZNiMbxzXQGRTjkCFO4QPlEK35upjsE=";
          })
          # Enable rounded window with no decoration
          (pkgs.fetchpatch {
            url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-30/round-undecorated-frame.patch";
            sha256 = "sha256-uYIxNTyfbprx5mCqMNFVrBcLeo+8e21qmBE3lpcnd+4=";
          })
          # Make Emacs aware of OS-level light/dark mode
          (pkgs.fetchpatch {
            url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-30/system-appearance.patch";
            sha256 = "sha256-3QLq91AQ6E921/W9nfDjdOUWR8YVsqBAT/W9c1woqAw=";
          })
        ];
    })
  );
in {
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
    packages =
      [
        (if pkgs.stdenv.isDarwin then darwinEmacs else pkgs.emacs)
        pkgs.pinentry-tty
        pkgs.prusa-slicer
      ]
      ++ lib.optionals (osConfig.networking.hostName == "melaan") [
        pkgs.prismlauncher
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
        (pkgs.aspellWithDicts (dicts: [
          dicts.en
          dicts.en-computers
          dicts.en-science
        ]))
        pkgs.babashka
        pkgs.bash
        pkgs.bash-language-server
        pkgs.clj-kondo
        pkgs.cljfmt
        pkgs.clojure
        pkgs.clojure-lsp
        pkgs.cmake
        pkgs.codex
        pkgs.coreutils-prefixed
        pkgs.discord
        pkgs.editorconfig-core-c
        pkgs.eslint
        pkgs.fd
        pkgs.gnupg
        pkgs.inkscape
        pkgs.insomnia
        pkgs.iterm2
        pkgs.logseq
        pkgs.metals
        pkgs.mkalias
        pkgs.mpv
        pkgs.multimarkdown
        pkgs.nil
        pkgs.nixfmt-rfc-style
        pkgs.nodePackages_latest.js-beautify
        pkgs.nodePackages_latest.nodejs
        pkgs.pinentry_mac
        pkgs.prettier
        pkgs.ripgrep
        pkgs.rsync
        pkgs.ruby-lsp
        pkgs.rubyPackages.solargraph
        pkgs.scalafmt
        pkgs.shellcheck
        pkgs.shfmt
        pkgs.stylelint
        pkgs.typescript
        pkgs.typescript-language-server
        pkgs.vscode-langservers-extracted
        pkgs.yaml-language-server
        inputs.zen-browser.packages.aarch64-darwin.default
      ];
  };

  fonts.packages = lib.mkIf pkgs.stdenv.isDarwin [
    pkgs.fira-code
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.symbols-only
  ];

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
      envExtra = ''
        if [ -f "$HOME/.iterm2_shell_integration.zsh" ]; then
          source "$HOME/.iterm2_shell_integration.zsh"
        fi
      '';
    };
  };

  services.emacs = lib.mkIf pkgs.stdenv.isDarwin {
    package = darwinEmacs;
    enable = true;
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
