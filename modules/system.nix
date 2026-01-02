{
  config,
  lib,
  pkgs,
  ...
}: {
  # NixOS-specific configuration
  system.autoUpgrade = lib.mkIf (!pkgs.stdenv.isDarwin) {
    enable = true;
    allowReboot = lib.mkIf (config.networking.hostName == "harmony") true;
    flake = "github:OscarMarshall/nix";
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  time.timeZone = lib.mkDefault "America/Los_Angeles";

  # NixOS-specific i18n and console settings
  i18n = lib.mkIf (!pkgs.stdenv.isDarwin) {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  console = lib.mkIf (!pkgs.stdenv.isDarwin) {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  programs.zsh.enable = true;
}
