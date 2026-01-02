{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}: {
  home = {
    username = "adelline";
    stateVersion = "25.05";

    packages = lib.mkIf (osConfig.networking.hostName == "melaan") (
      with pkgs; [
        google-chrome
        ghostty
        krita
        prismlauncher
        rnote
      ]
    );
  };

  programs = {
    home-manager.enable = true;
  };
}
