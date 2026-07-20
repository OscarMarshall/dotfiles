{
  my.ghostty = {
    hmDarwin = { pkgs, ... }: { programs.ghostty.package = pkgs.ghostty-bin; };

    homeManager = { lib, ... }: {
      programs.ghostty = {
        enable = true;

        settings = {
          auto-update = "off";
          keybind = [ "global:super+Backquote=toggle_quick_terminal" ];
          macos-option-as-alt = true;
          # Follow the system light/dark appearance instead of Stylix's single
          # (dark-only) base16 theme.
          theme = lib.mkForce "light:Catppuccin Latte,dark:Catppuccin Mocha";
        };
      };
    };
  };
}
