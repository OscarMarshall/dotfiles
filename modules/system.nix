{pkgs, ...}: {
  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
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

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  programs.zsh.enable = true;

  environment = {
    systemPackages = with pkgs; [
      emacs
      git
      wget
    ];
  };
}
