{
  config,
  inputs,
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

  # Darwin-specific configuration
  system = lib.mkIf pkgs.stdenv.isDarwin {
    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = lib.mkIf (config.networking.hostName == "omarshal-m-2fd2") 5;

    activationScripts.applications.text = let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = ["/Applications"];
      };
    in
      pkgs.lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
        while read -r src; do
          app_name=$(basename "$src")
          echo "copying $src" >&2
          ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
        done
      '';
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
