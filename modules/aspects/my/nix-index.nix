{ inputs, ... }: {
  flake-file.inputs.nix-index-database = {
    inputs.nixpkgs.follows = "nixpkgs";
    url = "github:nix-community/nix-index-database";
  };

  my.nix-index.homeManager = {
    imports = [ (inputs.nix-index-database.homeModules.default or { }) ];

    programs = {
      nix-index.enable = true;
      nix-index-database.comma.enable = true;
    };
  };
}
