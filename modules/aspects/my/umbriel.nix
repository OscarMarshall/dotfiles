# Umbriel - a wlroots/SceneFX Wayland compositor from the Noctalia project. Used as the session on
# tensoon, paired with the Noctalia shell (my.noctalia) and Noctalia Greeter (my.noctalia-greeter).
#
# No tagged releases yet; the flake input tracks `main`. The `git+https` URL with `?submodules=1` is
# required so the patched SceneFX fork in `subprojects/scenefx` is fetched.
#
# `hmLinux` forwarded from a host-level include only carries plain config, not module `imports`, so
# the flake's home-manager module is wired in via `home-manager.sharedModules` on the NixOS side and
# the user-facing `programs.umbriel` settings live under `hmLinux`.
{ inputs, ... }: {
  flake-file.inputs.umbriel = {
    url = "git+https://github.com/noctalia-dev/umbriel?submodules=1";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.umbriel = {
    hmLinux.programs.umbriel = {
      enable = true;

      settings = {
        general.autostart = [ "noctalia" ];

        # Programmer Dvorak as a second layout, toggle with both shifts. Plain US stays primary.
        input.keyboard = {
          options = "grp:alt_shift_toggle";
          layout = "us,us";
          variant = ",dvp";
        };

        keybinds = {
          Mod = "spawn:noctalia msg panel-toggle launcher";
          "Mod+O" = "overview-toggle";
          "Mod+Return" = "spawn:ghostty";
          "Mod+Shift+Q" = "window-close";
        };

        layout.gap = 8;
      };
    };

    nixos = {
      imports = [ inputs.umbriel.nixosModules.default ];
      home-manager.sharedModules = [ inputs.umbriel.homeModules.default ];
      programs.umbriel.enable = true;
    };
  };
}
