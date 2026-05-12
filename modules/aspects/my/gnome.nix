{
  my.gnome = {
    homeManager =
      { config, ... }:
      {
        # Keep gtk4 theme in sync with gtk3 to silence the warning about the
        # default changing from config.gtk.theme to null in Home Manager 26.05.
        gtk.gtk4.theme = config.gtk.theme;

        qt.platformTheme.name = "adwaita";

        # Stylix qt theming only supports qtct, not gnome; disable it and let
        # the adwaita platform theme handle qt styling on GNOME.
        stylix.targets.qt.enable = false;
      };

    nixos =
      { pkgs, ... }:
      {
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
  };
}
