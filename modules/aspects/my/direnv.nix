{
  my.direnv = { user, ... }: {
    homeManager = { pkgs, ... }: {
      programs.direnv = {
        enable = true;

        nix-direnv = {
          enable = true;
          # The default nix-direnv is built against CppNix, which doesn't know Lix's `flake-self-attrs` (enabled in
          # my.nix) and warns "unknown experimental feature" on every `use flake`.
          package = pkgs.lixPackageSets.stable.nix-direnv;
        };
      };
    };

    # The allow-list. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [ ".local/share/direnv" ];
  };
}
