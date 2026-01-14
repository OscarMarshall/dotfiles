{
  flake.modules.nixos.gnome = {pkgs, ...}: {
    environment = {
      gnome.excludePackages = with pkgs; [
        epiphany
        gnome-calendar
        gnome-console
        gnome-contacts
        gnome-maps
        gnome-tour
        gnome-user-docs
        gnome-weather
      ];

      systemPackages = with pkgs; [
        # Enable system tray icons
        gnomeExtensions.appindicator
      ];
    };

    # Automatic screen rotation
    hardware.sensor.iio.enable = true;

    services = {
      desktopManager.gnome.enable = true;
      displayManager.gdm.enable = true;
    };
  };
}
