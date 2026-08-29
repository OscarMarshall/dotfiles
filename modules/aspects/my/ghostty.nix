{
  my.ghostty = {
    hmDarwin = { pkgs, ... }: { programs.ghostty.package = pkgs.ghostty-bin; };

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
