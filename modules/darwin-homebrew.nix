{
  lib,
  pkgs,
  ...
}: {
  # Only apply on darwin systems
  config = lib.mkIf pkgs.stdenv.isDarwin {
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
        "discord"
        "gpg-suite"
        "logseq"
        "makemkv"
        "prismlauncher"
        "proton-mail"
        "prusaslicer"
        "steam"
      ];
    };
  };
}
