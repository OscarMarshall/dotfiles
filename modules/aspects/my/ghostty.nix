{
  my.ghostty = {
    homeManager.programs.ghostty = {
      enable = true;
      settings = {
        keybind = [ "global:super+Backquote=toggle_quick_terminal" ];
        macos-option-as-alt = true;
        auto-update = "off";
      };
    };

    hmDarwin = { pkgs, ... }: { programs.ghostty.package = pkgs.ghostty-bin; };
  };
}
