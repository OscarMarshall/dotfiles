{
  my.ghostty.homeManager = { pkgs, ... }: {
    # Without wl-copy/wl-paste on PATH, terminal apps (Claude Code, fish's Ctrl+V, editors) fall
    # back to OSC 52, which makes Ghostty the Wayland clipboard owner. Ghostty then keeps pasting
    # its own stale copy after another app (e.g. Zen) takes the clipboard. With wl-clipboard they
    # talk to the compositor directly and Ghostty never holds the selection.
    home.packages = [ pkgs.wl-clipboard ];

    programs.ghostty = {
      enable = true;

      settings = {
        auto-update = "off";
        background-opacity = 0.95;
        keybind = [ "global:super+Backquote=toggle_quick_terminal" ];
        # tensoon runs Umbriel with a global [input.touchpad] scroll_factor of 0.6, but Ghostty
        # re-quantises the scaled delta into its own wheel detents using mouse-scroll-multiplier,
        # whose touchpad ("precision") default is 1 - so scrolling inside a full-screen TUI
        # (claude) still runs far faster than everything else. precision:0.3 brings the terminal
        # back in line; discrete mice keep the default 3.
        mouse-scroll-multiplier = "precision:0.3,discrete:3";
        # Ghostty follows the system light/dark appearance on its own.
        theme = "light:Catppuccin Latte,dark:Catppuccin Mocha";
      };
    };
  };
}
