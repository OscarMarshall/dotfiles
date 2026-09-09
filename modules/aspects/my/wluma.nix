# wluma - automatic display brightness driven by the ambient light sensor (and, if it helps,
# screen contents). It is a per-user Wayland session daemon with no privileged component - it
# reads the ALS through iio-sensor-proxy's D-Bus and sets the backlight through logind - so it
# lives on the home-manager side (`services.wluma`, a stock home-manager module).
#
# On tensoon the ALS is already exposed: nixos-hardware's Framework module sets
# `hardware.sensor.iio.enable`, so wluma auto-detects the sensor, the eDP-1 panel and its
# /sys/class/backlight device, and the wlroots screen capturer with no config. The default
# `adaptive` predictor watches the brightnessctl changes from my.umbriel's XF86MonBrightness
# binds and gradually takes over.
#
# Wired like my.noctalia / my.umbriel, but through an `includes` list - the list form is only
# needed so one entry can take `{ user, ... }` to add the user to the `video` group.
{
  my.wluma.includes = [
    # Writing /sys/class/backlight/*/brightness directly (see the udev rule below) needs the
    # `video` group. Without it wluma still works via logind's SetBrightness D-Bus call, just
    # with steppier transitions.
    ({ user, ... }: { nixos.users.users.${user.userName}.extraGroups = [ "video" ]; })

    {
      hmLinux.services.wluma = {
        enable = true;

        settings = {
          # ALS, panel and capturer are all auto-detected (iio-sensor-proxy over D-Bus, then the
          # eDP-1 backlight, then wlr-screencopy). The one override: wluma otherwise takes
          # *exclusive* Wayland gamma control for its colour-temperature feature, which would
          # lock out Noctalia's `nightlight`. Drop gamma here so Noctalia keeps the night shift
          # and wluma only touches the backlight level.
          output.backlight = [
            {
              name = "eDP-1";
              gamma = false;
            }
          ];
        };

        # systemd.target defaults to home-manager's `wayland.systemd.target`, i.e.
        # graphical-session.target - which the Umbriel session brings up (same as noctalia.service).
        systemd.enable = true;
      };
    }

    {
      nixos = { pkgs, ... }: {
        # wluma's own 90-wluma-backlight.rules (nixpkgs' package does not install it): hand the
        # backlight / LED brightness attributes to the `video` group so wluma can fade them
        # directly instead of stepping through logind.
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
          ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
          ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness"
          ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
        '';
      };
    }
  ];
}
