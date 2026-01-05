{
  lib,
  pkgs,
  ...
}: {
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
    brews = [
      # No system-level Homebrew packages needed
    ];
    casks = [
      "arc"
      "dash"
      "gpg-suite"
      "makemkv"
      "proton-mail"
    ];
  };

  # Add Homebrew shell integration for zsh on darwin
  programs.zsh.interactiveShellInit = lib.mkIf pkgs.stdenv.isDarwin ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
  '';
}
