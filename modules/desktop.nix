{
  config,
  lib,
  pkgs,
  ...
}: lib.mkIf (config.networking.hostName == "melaan") {
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
}
