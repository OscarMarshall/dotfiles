{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../cachix.nix
    ../modules/users.nix
  ];

  # Nix settings
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = "melaan";
  networking.networkmanager.enable = true;

  # Time zone
  time.timeZone = "America/Los_Angeles";

  # Locale settings
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
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

  # GNOME Desktop Environment
  services.flatpak.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  environment.gnome.excludePackages = with pkgs; [
    epiphany
    gnome-calendar
    gnome-console
    gnome-contacts
    gnome-maps
    gnome-tour
    gnome-user-docs
    gnome-weather
  ];
  hardware.sensor.iio.enable = true;

  # Printing
  services.printing.enable = true;

  # Sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Additional user configuration
  users.users = {
    adelline = {
      extraGroups = ["networkmanager"];
      packages = with pkgs; [
        google-chrome
        ghostty
        krita
        rnote
      ];
    };
    oscar = {
      extraGroups = ["networkmanager"];
    };
  };

  # Programs
  programs = {
    steam.enable = true;
    zsh.enable = true;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System packages
  environment.systemPackages = with pkgs; [
    emacs
    gnomeExtensions.appindicator
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
