{ inputs, lib, ... }:

{
  flake-file.inputs.zen-browser.url = "github:0xc000022070/zen-browser-flake";

  my.zen-browser.homeManager = {
    imports = lib.optionals (inputs ? zen-browser) [ inputs.zen-browser.homeModules.twilight ];

    programs.zen-browser.enable = true;
  };
}
