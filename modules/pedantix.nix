{ inputs, ... }:

{
  flake-file.inputs.pedantix = {
    inputs.nixpkgs.follows = "nixpkgs";
    url = "github:Swarsel/pedantix";
  };

  imports = [ (inputs.pedantix.flakeModules.default or { }) ];

  perSystem.treefmt.programs.pedantix.enable = true;
}
