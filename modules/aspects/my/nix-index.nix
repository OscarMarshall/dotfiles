{ inputs, ... }: {
  flake-file.inputs.nix-index-database = {
    url = "github:nix-community/nix-index-database";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.nix-index.homeManager = { pkgs, ... }: {
    imports = [ (inputs.nix-index-database.homeModules.default or { }) ];

    # Rebuild the module's comma-with-db ourselves (instead of `programs.nix-index-database.comma.enable`) so comma
    # bakes in Lix rather than nixpkgs' default CppNix, which doesn't know Lix's `flake-self-attrs` (enabled in my.nix)
    # and warns "unknown experimental feature" on every run.
    home.packages = [
      (pkgs.callPackage "${inputs.nix-index-database}/comma-wrapper.nix" {
        comma = pkgs.comma.override { nix = pkgs.lixPackageSets.stable.lix; };
        nix-index-database = (import inputs.nix-index-database { inherit pkgs; }).nix-index-small-database;
      })
    ];

    programs.nix-index.enable = true;
  };
}
