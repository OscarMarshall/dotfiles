# NOTE: I'd prefer to use pkgs.ghostty-bin for darwin, but that stopped working.

{ den, ... }:
{
  oscarmarshall.ghostty = den.lib.parametric {
    includes = [
      (
        { host, ... }:
        {
          homeManager =
            { pkgs, ... }:
            {
              programs.ghostty = {
                enable = true;
                package = if (host.class == "darwin") then null else pkgs.ghostty;
                settings = {
                  font-family = "fira-code";
                  keybind = [ "global:super+$=toggle_quick_terminal" ];
                  theme = "light:Catppuccin Latte,dark:Catppuccin Mocha";
                };
              };
            };
        }
      )
    ];

    darwin.homebrew.casks = [ "ghostty" ];
  };
}
