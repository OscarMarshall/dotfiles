{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # Custom Emacs with darwin-specific patches
  darwinEmacs = (pkgs.emacs.override {withNativeCompilation = true;}).overrideAttrs (old: {
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
  });
in {
  # Only apply on darwin systems
  config = lib.mkIf pkgs.stdenv.isDarwin {
    environment.systemPackages = [
      darwinEmacs
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
      pkgs.editorconfig-core-c
      pkgs.eslint
      pkgs.fd
      pkgs.gnupg
      pkgs.inkscape
      pkgs.insomnia
      pkgs.iterm2
      pkgs.metals
      pkgs.mkalias
      pkgs.mpv
      pkgs.multimarkdown
      pkgs.nil
      pkgs.nixfmt-rfc-style
      pkgs.nodePackages_latest.js-beautify
      pkgs.nodePackages_latest.nodejs
      pkgs.prettier
      pkgs.pinentry_mac
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

    fonts.packages = [
      pkgs.fira-code
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.symbols-only
    ];

    services.emacs = {
      package = darwinEmacs;
      enable = true;
    };
  };
}
