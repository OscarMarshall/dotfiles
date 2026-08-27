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

      # Match this repo's stylix Catppuccin Mocha. Everything else is best set in Noctalia's own
      # settings UI first, then promoted here once it settles.
      settings.theme = {
        builtin = "Catppuccin";
        mode = "dark";
        source = "builtin";
      };

      # User service, PartOf graphical-session.target - Umbriel brings it up via autostart too; the
      # service keeps it supervised and restarted on failure.
      systemd.enable = true;
    };

    nixos = {
      imports = [ inputs.noctalia.nixosModules.default ];
      home-manager.sharedModules = [ inputs.noctalia.homeModules.default ];

      programs.noctalia = {
        # The NixOS `enable` is separate from the home-manager one; without it the module's whole
        # config block (recommendedServices included) is inert.
        enable = true;
        # NetworkManager, bluetooth, UPower and power-profiles-daemon - the services Noctalia's
        # control center drives.
        recommendedServices.enable = true;
      };
    };
  };
}
