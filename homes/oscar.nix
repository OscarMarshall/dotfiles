{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}: {
  imports = [
    ./modules/clojure.nix
    ./modules/darwin-packages.nix
    ./modules/desktop-environment.nix
    ./modules/direnv.nix
    ./modules/emacs.nix
    ./modules/fzf.nix
    ./modules/git.nix
    ./modules/packages.nix
    ./modules/starship.nix
    ./modules/zsh.nix
  ];

  home = {
    username = "oscar";
    shell.enableZshIntegration = true;
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
