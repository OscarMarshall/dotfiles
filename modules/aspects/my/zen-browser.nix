{ inputs, ... }:

{
  flake-file.inputs.zen-browser = {
    inputs = {
      home-manager.follows = "home-manager";
      nixpkgs.follows = "nixpkgs";
    };
    url = "github:0xc000022070/zen-browser-flake";
  };

  my.zen-browser.homeManager = {
    imports = [ (inputs.zen-browser.homeModules.twilight or { }) ];

    programs.zen-browser.enable = true;
  };
}
