{
  den,
  inputs,
  lib,
  ...
}:

{
  flake-file.inputs.nix-doom-emacs-unstraightened.url = "github:marienz/nix-doom-emacs-unstraightened";

  oscarmarshall.emacs = den.lib.parametric {
    includes = [
      (den._.unfree [ "aspell-dict-en-science" ])
      (
        { HM-OS-USER }:
        {
          homeManager =
            { pkgs, ... }:
            {
              programs.doom-emacs.emacs =
                with pkgs;
                emacs-pgtk.overrideAttrs (old: {
                  patches =
                    (old.patches or [ ])
                    ++ lib.optionals (HM-OS-USER.host.class == "darwin") [
                      # fix-window-role
                      (fetchpatch {
                        url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/a18d28c5044c98c81971679be819c0a1afb38a5f/patches/emacs-28/fix-window-role.patch";
                        sha256 = "sha256-+z/KfsBm1lvZTZNiMbxzXQGRTjkCFO4QPlEK35upjsE=";
                      })
                      # system-appearance
                      (fetchpatch {
                        url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/a18d28c5044c98c81971679be819c0a1afb38a5f/patches/emacs-30/system-appearance.patch";
                        sha256 = "sha256-3QLq91AQ6E921/W9nfDjdOUWR8YVsqBAT/W9c1woqAw=";
                      })
                      # round-undecorated-frame
                      (fetchpatch {
                        url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/a18d28c5044c98c81971679be819c0a1afb38a5f/patches/emacs-30/round-undecorated-frame.patch";
                        sha256 = "sha256-uYIxNTyfbprx5mCqMNFVrBcLeo+8e21qmBE3lpcnd+4=";
                      })
                      # fix-macos-tahoe-scrolling
                      (fetchpatch {
                        url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/a18d28c5044c98c81971679be819c0a1afb38a5f/patches/emacs-30/fix-macos-tahoe-scrolling.patch";
                        sha256 = "sha256-598LbU3Oa2TLOIltr6cMsuOolPtbJY3yBVUCAmE/SVA=";
                      })
                    ];
                });
            };
        }
      )
    ];

    homeManager =
      { pkgs, ... }:
      {
        imports = lib.optionals (inputs ? nix-doom-emacs-unstraightened) [ inputs.nix-doom-emacs-unstraightened.homeModule ];

        home.sessionVariables.EDITOR = "emacs";

        programs.doom-emacs = {
          enable = true;
          doomDir = ./doom;
          extraBinPackages = with pkgs; [
            coreutils
            fd
            git
            ripgrep

            (aspellWithDicts (dicts: [
              dicts.en
              dicts.en-computers
              dicts.en-science
            ]))
            babashka
            bash-language-server
            clj-kondo
            cljfmt
            clojure
            clojure-lsp
            cmake
            editorconfig-core-c
            eslint
            metals
            multimarkdown
            nixd
            nixfmt
            nodePackages_latest.js-beautify
            nodePackages_latest.nodejs
            pinentry-emacs
            prettier
            ruby-lsp
            rubyPackages.solargraph
            scalafmt
            shellcheck
            shfmt
            stylelint
            typescript
            typescript-language-server
            vscode-langservers-extracted
            yaml-language-server
          ];
          extraPackages = epkgs: [ epkgs.treesit-grammars.with-all-grammars ];
        };

        services.emacs.enable = true;
      };
  };
}
