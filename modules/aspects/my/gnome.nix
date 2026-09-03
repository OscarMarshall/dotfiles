{
  my.gnome = {
    hmLinux.dconf.enable = true;

    nixos = { pkgs, ... }: {
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

        # Run Chromium/Electron/Ozone apps as native Wayland clients instead of XWayland.
        # nixpkgs' google-chrome wrapper only adds `--ozone-platform-hint=auto` when this is
        # set; without it Chrome runs on XWayland, which mishandles the touchpad's
        # high-resolution scroll axis and scrolls far too fast on the Framework.
        sessionVariables.NIXOS_OZONE_WL = "1";

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
