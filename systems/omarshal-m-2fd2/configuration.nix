{
  config,
  inputs,
  pkgs,
  ...
}: let
  emacs = (pkgs.emacs.override {withNativeCompilation = true;}).overrideAttrs (old: {
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
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = [
    emacs
    (pkgs.aspellWithDicts (dicts: [
      dicts.en
      dicts.en-computers
      dicts.en-science
    ]))
    pkgs.babashka
    pkgs.bash
    pkgs.bash-language-server
    # pkgs.blender
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
    #pkgs.logseq
    pkgs.metals
    pkgs.mkalias
    #pkgs.mkvtoolnix
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

  nix.settings = {
    # Necessary for using flakes on this system.
    experimental-features = "nix-command flakes";

    substituters = [
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  system = {
    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 5;

    primaryUser = "omarshal";

    activationScripts.applications.text = let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = ["/Applications"];
      };
    in
      pkgs.lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
        while read -r src; do
          app_name=$(basename "$src")
          echo "copying $src" >&2
          ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
        done
      '';
  };

  nixpkgs = {
    # The platform the configuration will be used on.
    hostPlatform = "aarch64-darwin";

    config.allowUnfree = true;
  };

  services = {
    emacs = {
      package = emacs;
      enable = true;
    };
  };

  users.users = {
    omarshal = {
      description = "Oscar Marshall";
      home = pkgs.lib.mkDefault /Users/omarshal;
      shell = pkgs.zsh;
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
    brews = [
      "rbenv"
    ];
    casks = [
      "arc"
      "dash"
      "discord"
      "gpg-suite"
      "logseq"
      "makemkv"
      "prismlauncher"
      "proton-mail"
      "prusaslicer"
      "steam"
    ];
  };
}
