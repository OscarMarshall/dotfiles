{
  config,
  lib,
  pkgs,
  ...
}: lib.mkIf (config.networking.hostName == "melaan") {
  # GNOME Desktop Environment
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

  # GNOME Extensions
  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator
  ];
}
