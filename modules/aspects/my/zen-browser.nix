{ inputs, ... }:

{
  flake-file.inputs.zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    inputs = {
      home-manager.follows = "home-manager";
      nixpkgs.follows = "nixpkgs";
    };
  };

  my.zen-browser.homeManager = {
    imports = [ (inputs.zen-browser.homeModules.twilight or { }) ];

    programs.zen-browser.enable = true;

    # Stylix zen-browser theming requires profile names to be declared; since
    # profiles are managed outside of Nix, disable the stylix target instead.
    stylix.targets.zen-browser.enable = false;
  };
}
