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

  home = {
    username = lib.mkForce "omarshal";
    sessionVariables = {
      ITERM2_SQUELCH_MARK = 1;
    };
  };

  programs = {
    java.enable = true;
    rbenv.enable = true;
  };
}
