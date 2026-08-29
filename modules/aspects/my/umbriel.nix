# Umbriel - a wlroots/SceneFX Wayland compositor from the Noctalia project. Used as the session on
# tensoon, paired with the Noctalia shell (my.noctalia) and Noctalia Greeter (my.noctalia-greeter).
#
# No tagged releases yet; the flake input tracks `main`. The `git+https` URL with `?submodules=1` is
# required so the patched SceneFX fork in `subprojects/scenefx` is fetched.
#
# `hmLinux` forwarded from a host-level include only carries plain config, not module `imports`, so
# the flake's home-manager module is wired in via `home-manager.sharedModules` on the NixOS side and
# the user-facing `programs.umbriel` settings live under `hmLinux`.
{ lib, inputs, ... }:
let
  # Laptop function row. `allow_when_locked` so volume/brightness still work at the lock screen.
  # wpctl comes from wireplumber; brightnessctl and playerctl are added on the NixOS side below.
  lockable = action: {
    inherit action;
    allow_when_locked = true;
  };
  mediaKeybinds = {
    XF86AudioLowerVolume = lockable "spawn:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    XF86AudioMicMute = lockable "spawn:wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
    XF86AudioMute = lockable "spawn:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
    XF86AudioNext = "spawn:playerctl next";
    XF86AudioPlay = "spawn:playerctl play-pause";
    XF86AudioPrev = "spawn:playerctl previous";
    XF86AudioRaiseVolume = lockable "spawn:wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
    XF86MonBrightnessDown = lockable "spawn:brightnessctl set 5%-";
    XF86MonBrightnessUp = lockable "spawn:brightnessctl set 5%+";
  };
  # Scrolling layout: Left/Right walk the strip, Up/Down walk a column, Shift moves instead of focuses.
  navigationKeybinds = {
    "Mod+Comma" = "workspace-previous";
    "Mod+Down" = "window-focus-down";
    "Mod+End" = "column-focus-last";
    "Mod+Home" = "column-focus-first";
    "Mod+Left" = "window-focus-left";
    "Mod+O" = "overview-toggle";
    "Mod+Period" = "workspace-next";
    "Mod+Right" = "window-focus-right";
    "Mod+Shift+Comma" = "window-move-to-workspace-previous";
    "Mod+Shift+Down" = "window-move-down";
    "Mod+Shift+Left" = "column-move-left";
    "Mod+Shift+Period" = "window-move-to-workspace-next";
    "Mod+Shift+Right" = "column-move-right";
    "Mod+Shift+Up" = "window-move-up";
    "Mod+Up" = "window-focus-up";
    # The Framework key (bottom-right, sends XF86AudioMedia) cycles input.keyboard.layout
    # entries (US <-> Programmer Dvorak).
    XF86AudioMedia = "keyboard-layout-next";
  };
  # Scratchpad: a per-output holding area for windows (docs/user/scratchpad.md). Matches
  # Umbriel's packaged config verbatim, so the upstream docs apply as written.
  #   Mod+Space        show / hide the scratchpad
  #   Mod+Shift+Space  stash the focused workspace window
  #   Mod+Ctrl+Space   return the focused scratchpad window to its workspace
  #   Mod+Tab          cycle focus among visible scratchpad windows
  scratchpadKeybinds = {
    "Mod+Ctrl+Space" = "window-restore-from-scratchpad";
    "Mod+Shift+Space" = "window-move-to-scratchpad";
    "Mod+Space" = "scratchpad-toggle";
    "Mod+Tab" = "scratchpad-focus-next";
  };
  # Keybinds, grouped so the merged result stays readable after the formatter sorts each attrset.
  # `Mod` is Super in a real session. Actions: see the Umbriel docs (docs/user/{keybinds,actions}.md).
  shellKeybinds = {
    Mod = "spawn:noctalia msg panel-toggle launcher";
    "Mod+B" = "spawn:noctalia msg panel-toggle wallpaper";
    "Mod+Escape" = "spawn:noctalia msg panel-toggle session";
    "Mod+Return" = "spawn:ghostty";
    # Umbriel's own overlay listing every active keybind (also shown once at startup).
    "Mod+Slash" = "cheatsheet-toggle";
    "Mod+V" = "spawn:noctalia msg panel-toggle clipboard";
    "Mod+X" = "spawn:noctalia msg bar-toggle";
    Print = "spawn:noctalia msg screenshot-region";
    "Shift+Print" = "spawn:noctalia msg screenshot-fullscreen";
  };
  windowKeybinds = {
    "Mod+C" = "column-center";
    "Mod+F" = "window-toggle-fullscreen";
    "Mod+M" = "window-toggle-maximize";
    "Mod+P" = "window-toggle-pinned";
    "Mod+R" = "window-cycle-width";
    "Mod+Shift+Q" = "window-close";
    "Mod+Shift+R" = "window-cycle-width-back";
    "Mod+Shift+T" = "window-focus-switch-floating";
    "Mod+T" = "window-toggle-floating";
  };
  workspaceKeybinds = lib.listToAttrs (
    lib.concatMap (
      {
        digit,
        sym,
        ws,
      }:
      let
        target = toString ws;
      in
      lib.concatMap
        (key: [
          (lib.nameValuePair "Mod+${key}" "workspace-switch:${target}")
          (lib.nameValuePair "Mod+Shift+${key}" "window-move-to-workspace:${target}")
        ])
        [
          digit
          sym
        ]
    ) workspaceKeys
  );
  # Mod+<key> focuses a workspace, Mod+Shift+<key> sends the focused window there.
  #
  # Umbriel matches a bind against both the produced keysym and the physical key's level-0
  # (unshifted) keysym, with an exact modifier match. On Programmer Dvorak the digits live on
  # the Shift layer, so plain Mod+<digit> can never fire. Bind each workspace to its digit and
  # to the symbol Programmer Dvorak leaves unshifted on that key:
  #   1 (   2 )   3 }   4 +   5 {   6 ]   7 [   8 !   9 =   0 *
  workspaceKeys = [
    {
      digit = "1";
      sym = "parenleft";
      ws = 1;
    }
    {
      digit = "2";
      sym = "parenright";
      ws = 2;
    }
    {
      digit = "3";
      sym = "braceright";
      ws = 3;
    }
    {
      digit = "4";
      sym = "plus";
      ws = 4;
    }
    {
      digit = "5";
      sym = "braceleft";
      ws = 5;
    }
    {
      digit = "6";
      sym = "bracketright";
      ws = 6;
    }
    {
      digit = "7";
      sym = "bracketleft";
      ws = 7;
    }
    {
      digit = "8";
      sym = "exclam";
      ws = 8;
    }
    {
      digit = "9";
      sym = "equal";
      ws = 9;
    }
    {
      digit = "0";
      sym = "asterisk";
      ws = 10;
    }
  ];
in
{
  flake-file.inputs.umbriel = {
    url = "git+https://github.com/noctalia-dev/umbriel?submodules=1";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.umbriel = {
    hmLinux.programs.umbriel = {
      enable = true;

      settings = {
        general.autostart = [ "noctalia" ];

        input = {
          # Programmer Dvorak as a second layout; plain US stays primary. Switch with the
          # Framework key (XF86AudioMedia -> keyboard-layout-next) below.
          keyboard = {
            layout = "us,us";
            variant = ",dvp";
          };

          # tensoon is a Framework 13 laptop - natural (content-follows-finger) touchpad scrolling.
          touchpad.natural_scroll = true;
        };

        keybinds =
          shellKeybinds // windowKeybinds // scratchpadKeybinds // navigationKeybinds // workspaceKeybinds // mediaKeybinds;

        layout.gap = 8;
        # Framework 13's internal panel (2256x1504). 1.5x fractional scale.
        output.eDP-1.scale = 1.5;
      };
    };

    nixos = { pkgs, ... }: {
      imports = [ inputs.umbriel.nixosModules.default ];

      # Spawn targets for the media/brightness keybinds above (wpctl comes from wireplumber).
      environment.systemPackages = with pkgs; [
        brightnessctl
        playerctl
      ];

      home-manager.sharedModules = [ inputs.umbriel.homeModules.default ];
      programs.umbriel.enable = true;
    };
  };
}
