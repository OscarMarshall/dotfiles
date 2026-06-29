{ den, inputs, ... }:

{
  flake-file.inputs.nix-doom-emacs-unstraightened = {
    url = "github:marienz/nix-doom-emacs-unstraightened";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      systems.follows = "systems";
    };
  };

  my.emacs = {
    includes = [ (den._.unfree [ "aspell-dict-en-science" ]) ];

    homeManager = { pkgs, ... }: {
      imports = [ (inputs.nix-doom-emacs-unstraightened.homeModule or { }) ];

      home.sessionVariables.EDITOR = "emacs -nw";

      programs.doom-emacs = {
        enable = true;
        doomDir = ./doom;
        experimentalFetchTree = true;
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
          gnupg
          metals
          multimarkdown

          lix
          nixd
          nixfmt

          js-beautify
          nodejs
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

    hmDarwin = { pkgs, ... }: {
      programs.doom-emacs.emacs =
        with pkgs;
        emacs-pgtk.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            # fix-window-role
            (fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/d60d824b3d622f423c822b487a567805a195ac91/patches/emacs-28/fix-window-role.patch";
              sha256 = "sha256-+z/KfsBm1lvZTZNiMbxzXQGRTjkCFO4QPlEK35upjsE=";
            })
            # system-appearance
            (fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/d60d824b3d622f423c822b487a567805a195ac91/patches/emacs-30/system-appearance.patch";
              sha256 = "sha256-3QLq91AQ6E921/W9nfDjdOUWR8YVsqBAT/W9c1woqAw=";
            })
            # round-undecorated-frame
            (fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/d60d824b3d622f423c822b487a567805a195ac91/patches/emacs-30/round-undecorated-frame.patch";
              sha256 = "sha256-fesZ0H3LO6T2AiRV8ASozKxZBpvVzwLEcLDy6rctR6c=";
            })
            # fix-macos-tahoe-scrolling
            (fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/d60d824b3d622f423c822b487a567805a195ac91/patches/emacs-30/fix-macos-tahoe-scrolling.patch";
              sha256 = "sha256-Hf9oZ5ImBnxTLa6yS02UDzBEgJEGAwNq/svJ3S35uKw=";
            })
            # fix-ns-x-colors
            (fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/d60d824b3d622f423c822b487a567805a195ac91/patches/emacs-30/fix-ns-x-colors.patch";
              sha256 = "sha256-oe3DFgEXwp0cZJl+ufWqTonaeWSliikTRsVDNbcy4Yw=";
            })
          ];
        });
    };
  };
}
