# Noctalia v5 - a native Wayland desktop shell (bar, launcher, control center, notifications, lock
# screen, wallpaper, clipboard history). Runs on top of a compositor; on tensoon that is Umbriel
# (my.umbriel). v5 is in beta; the flake input tracks `main`.
#
# The flake's modules `disabledModules` the nixpkgs ones and default `programs.noctalia.package` to
# the flake's own source build (matches the "follow main" choice). Point `package` at `pkgs.noctalia`
# if the source rebuilds get tiresome.
#
# As with my.umbriel, the home-manager module is wired via `home-manager.sharedModules` (a host-level
# `hmLinux` forward carries only plain config, not module `imports`).
{ inputs, ... }: {
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.noctalia = {
    hmLinux.programs.noctalia = {
      enable = true;

      # Promoted from the Noctalia settings menu (~/.local/state/noctalia/settings.toml).
      # Runtime edits through the UI still take precedence; this is the declarative baseline.
      # Left in the runtime file on purpose: config_version (metadata), the lockscreen_widgets
      # editor geometry, and wallpaper.{default,last} (a /nix/store path that rots on update).
      settings = {
        # Bar layout: audio visualiser + media on the left, date/weather/notifications in the
        # centre; right side is keyboard-layout + caffeine + system indicators (the clipboard,
        # wallpaper and brightness buttons were removed via the UI).
        bar.default = {
          center = [
            "date"
            "clock"
            "weather"
            "notifications"
          ];

          end = [
            "tray"
            "keyboard_layout"
            "caffeine"
            "network"
            "bluetooth"
            "volume"
            "battery"
            "session"
          ];

          start = [
            "control-center"
            "launcher"
            "workspaces"
            "media"
            "audio_visualizer"
          ];
        };

        location.auto_locate = true;
        # Custom lockscreen widgets are off. Their editor geometry (per-output pixel coords) is
        # deliberately left in the runtime settings.toml rather than promoted here.
        lockscreen_widgets.enabled = false;
        nightlight.enabled = true;

        shell = {
          # Short tags for the keyboard-layout widget in place of the full XKB description.
          keyboard_layout.custom_labels = {
            "English (US)" = "US";
            "English (programmer Dvorak)" = "DV";
          };

          # "Setup wizard done" is tracked by a marker in ~/.local/state/noctalia, which tensoon's
          # tmpfs root drops every boot - so the "Welcome to Noctalia" panel pops on every login.
          # Every real setting is already declared here, so switch the wizard off.
          setup_wizard_enabled = false;
        };

        # Bundled Catppuccin; `auto` follows the system/location light-dark schedule.
        theme = {
          builtin = "Catppuccin";
          mode = "auto";
          source = "builtin";
        };

        # Since Stylix was removed, Noctalia's own templates theme external apps: the gtk3/gtk4
        # templates drop a noctalia.css next to gtk.css and flip `gsettings color-scheme` +
        # adw-gtk3 on mode change; the qt template writes a qt6ct colour scheme. The nixos block
        # below installs adw-gtk3, dconf and qt6ct so those steps land.
        theme.templates = {
          builtin_ids = [
            "gtk3"
            "gtk4"
            "qt"
          ];

          enable_builtin_templates = true;
        };

        weather.unit = "imperial";

        widget = {
          clock.anchor = true;
          date.format = "{:%F}";
          keyboard_layout.show_glyph = false;
          media.hide_when_no_media = true;
          network.show_label = false;
          notifications.hide_when_no_unread = true;
          volume.show_label = false;
          weather.show_condition = false;
        };
      };

      # User service, PartOf graphical-session.target - Umbriel brings it up via autostart too;
      # the service keeps it supervised and restarted on failure.
      systemd.enable = true;
    };

    nixos = { pkgs, ... }: {
      imports = [ inputs.noctalia.nixosModules.default ];

      # Runtime support for the Noctalia gtk/qt theme templates (see settings.theme.templates):
      # adw-gtk3 is the light/dark GTK theme the gtk template switches to; qt6ct reads the
      # colour scheme the qt template drops in ~/.config/qt6ct/colors/.
      environment.systemPackages = [
        pkgs.adw-gtk3
        pkgs.qt6Packages.qt6ct
      ];

      home-manager.sharedModules = [ inputs.noctalia.homeModules.default ];

      programs = {
        dconf.enable = true;

        noctalia = {
          # The NixOS `enable` is separate from the home-manager one; without it the module's whole
          # config block (recommendedServices included) is inert.
          enable = true;
          # NetworkManager, bluetooth, UPower and power-profiles-daemon - the services Noctalia's
          # control center drives.
          recommendedServices.enable = true;
        };
      };

      qt = {
        enable = true;
        platformTheme = "qt5ct";
      };
    };
  };
}
