{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}: {
  imports = [
    ./oscar/emacs.nix
    ./oscar/packages.nix
    ./oscar/programs.nix
  ];

  home = {
    username = "oscar";
    shell.enableZshIntegration = true;
    stateVersion = "25.05";
  };
}
