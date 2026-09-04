# disko - declarative disk partitioning/formatting. The layout itself lives per-host (see
# modules/aspects/hosts/<host>/disk.nix); this aspect just wires in the module.
{ inputs, ... }: {
  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.disko.nixos.imports = [ inputs.disko.nixosModules.disko ];
}
