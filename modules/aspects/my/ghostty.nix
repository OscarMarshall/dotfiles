{
  my.ghostty = {
    homeManager = { lib, ... }: {
      programs.ghostty = {
        enable = true;
        settings = {
          keybind = [ "global:super+Backquote=toggle_quick_terminal" ];
          macos-option-as-alt = true;
          auto-update = "off";

          # Follow the system light/dark appearance instead of Stylix's single
          # (dark-only) base16 theme.
          theme = lib.mkForce "light:Catppuccin Latte,dark:Catppuccin Mocha";
        };
      };
    };

    hmDarwin = { pkgs, ... }: { programs.ghostty.package = pkgs.ghostty-bin; };
  };
}
