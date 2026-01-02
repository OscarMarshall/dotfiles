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
        # rbenv is handled by home-manager
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
