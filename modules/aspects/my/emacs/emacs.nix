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
    };
  };

  my.emacs = { user, ... }: {
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

          (aspellWithDicts (dicts: [ dicts.en ]))
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

    # nix-doom-emacs-unstraightened keeps DOOMDIR / the Emacs profile in the store; the only
    # writable state is DOOMLOCALDIR, which the home-manager module defaults to
    # ~/.local/share/nix-doom. It holds recentf / savehist / bookmarks / projectile / persp
    # sessions and the native-comp eln-cache (minutes to rebuild). `preserve`
    # (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [ ".local/share/nix-doom" ];
  };
}
