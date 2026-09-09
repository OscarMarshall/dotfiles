{ den, inputs, ... }:

{
  flake-file.inputs.nix-doom-emacs-unstraightened = {
    url = "github:marienz/nix-doom-emacs-unstraightened";

    inputs = {
      # Unused: we set `doomDir` explicitly below instead of relying on this
      # input's default. Left unfollowed, it resolves to a mutable relative
      # `path` input inside nix-doom-emacs-unstraightened, which Lix refuses
      # to write into our (immutable, git-committed) flake.lock.
      doomdir.follows = "nixpkgs";
      nixpkgs.follows = "nixpkgs";
      systems.follows = "systems";
    };
  };

  my.emacs = {
    includes = [ (den._.unfree [ "aspell-dict-en-science" ]) ];

    hmDarwin = { pkgs, ... }: {
      programs.doom-emacs.emacs =
        with pkgs;
        emacs-pgtk.overrideAttrs (old: {
          # macOS-only cosmetic/behavioural patches, lifted from d12frosted's
          # homebrew-emacs-plus emacs-plus@31 formula (all of its emacs-31
          # patches, in formula order). Pinned to the last commit that touched
          # patches/emacs-31/. `fix-window-role` and `fix-macos-tahoe-scrolling`
          # are gone: both are fixed upstream in Emacs 31.
          patches = (old.patches or [ ]) ++ [
            # fix-ns-x-colors
            (fetchpatch {
              sha256 = "sha256-oe3DFgEXwp0cZJl+ufWqTonaeWSliikTRsVDNbcy4Yw=";
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/ef1ccd601b865ab9422a30ec711ea0f9fc8fbf9a/patches/emacs-31/fix-ns-x-colors.patch";
            })
            # system-appearance
            (fetchpatch {
              sha256 = "sha256-4+2U+4+2tpuaThNJfZOjy1JPnneGcsoge9r+WpgNDko=";
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/ef1ccd601b865ab9422a30ec711ea0f9fc8fbf9a/patches/emacs-31/system-appearance.patch";
            })
            # round-undecorated-frame
            (fetchpatch {
              sha256 = "sha256-KCMEvJzN1OkwFYoMLpZghvdeoO1Ckcxk3Mo19YAf850=";
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/ef1ccd601b865ab9422a30ec711ea0f9fc8fbf9a/patches/emacs-31/round-undecorated-frame.patch";
            })
            # fix-ns-scroll-crash
            (fetchpatch {
              sha256 = "sha256-syC9un5Vy1+bmBWIc+TEwTCM/nfPIxd4IhWYdEfP4qE=";
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/ef1ccd601b865ab9422a30ec711ea0f9fc8fbf9a/patches/emacs-31/fix-ns-scroll-crash.patch";
            })
          ];
        });
    };

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
  };
}
