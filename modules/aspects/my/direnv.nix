{
  my.direnv.homeManager = { pkgs, ... }: {
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
}
