{ lib, inputs, ... }: {
  flake-file = {
    inputs.nix-logseq-git-flake.url = "github:Bad3r/nix-logseq-git-flake";

    nixConfig = {
      extra-substituters = [ "https://nix-logseq-git-flake.cachix.org" ];
      extra-trusted-public-keys = [ "nix-logseq-git-flake.cachix.org-1:DSBNW07PSRyCvS926tpIWahb53OIydwwZhsP6LhJNZo=" ];
    };
  };

  my.logseq =
    {
      cli-only ? false,
      ...
    }:
    { user, ... }:
    {
      homeManager = { pkgs, ... }: {
        home.packages = [
          inputs.nix-logseq-git-flake.packages.${pkgs.stdenv.hostPlatform.system}.logseq-cli
        ]
        ++ lib.optional (!cli-only) inputs.nix-logseq-git-flake.packages.${pkgs.stdenv.hostPlatform.system}.logseq;
      };
    }
    // lib.optionalAttrs (!cli-only) {
      # GUI only: recent-graph list, installed plugins and settings (~/.logseq) plus the Electron
      # window state (~/.config/Logseq). The graph's own markdown lives wherever the user put it -
      # typically ~/Projects or ~/Documents, already preserved. `preserve`
      # (modules/aspects/my/preserve.nix) is inert without my.preservation.
      preserve.users.${user.userName}.directories = [
        ".logseq"
        ".config/Logseq"
      ];
    };
}
