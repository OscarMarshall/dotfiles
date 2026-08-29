{
  my.ghostty = {
    hmDarwin = { pkgs, ... }: { programs.ghostty.package = pkgs.ghostty-bin; };
    # tensoon runs Umbriel with a global [input.touchpad] scroll_factor of 0.6, but Ghostty
    # re-quantises the scaled delta into its own wheel detents using mouse-scroll-multiplier,
    # whose touchpad ("precision") default is 1 - so scrolling inside a full-screen TUI (claude)
    # still runs far faster than everything else. precision:0.1 brings the terminal back in line;
    # discrete mice keep the default 3. Linux-only: macOS has no such compounding, and slowing
    # scroll there would just feel sluggish.
    hmLinux.programs.ghostty.settings.mouse-scroll-multiplier = "precision:0.1,discrete:3";

    homeManager.programs.ghostty = {
      enable = true;

      settings = {
        auto-update = "off";
        background-opacity = 0.95;
        macos-option-as-alt = true;
        # Ghostty follows the system light/dark appearance on its own.
        theme = "light:Catppuccin Latte,dark:Catppuccin Mocha";
      };
    };
  };
}
