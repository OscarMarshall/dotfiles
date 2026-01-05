{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}: {
  imports = [
    ./oscar.nix
    inputs.zen-browser.homeModules.twilight
  ];

  home.username = lib.mkForce "omarshal";

  programs.java.enable = true;
}
