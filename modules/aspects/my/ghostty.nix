# NOTE: I'd prefer to use pkgs.ghostty-bin for darwin, but that stopped working.

{ den, lib, ... }:
{
  my.ghostty = den.lib.parametric {
    includes = [
      (
        { host, ... }:
        {
          homeManager = {
            programs.ghostty = lib.mkIf (host.class == "darwin") {
              package = null;
              settings.macos-option-as-alt = true;
            };
          };
        }
      )
    ];

    darwin.homebrew.casks = [ "ghostty" ];

    homeManager.programs.ghostty = {
      enable = true;
      settings = {
        font-family = "fira-code";
        keybind = [ "global:super+Backquote=toggle_quick_terminal" ];
        theme = "light:Catppuccin Latte,dark:Catppuccin Mocha";
      };
    };
  };
}
