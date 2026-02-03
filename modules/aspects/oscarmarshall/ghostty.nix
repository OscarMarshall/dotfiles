{
  oscarmarshall.ghostty =
    { HM-OS-USER }:
    {
      homeManager =
        { pkgs, ... }:
        {
          programs.ghostty = {
            enable = HM-OS-USER.user.graphical;
            package = if (HM-OS-USER.host.class == "darwin") then pkgs.ghostty-bin else pkgs.ghostty;
            settings = {
              font-family = "fira-code";
              keybind = [
                (
                  if (HM-OS-USER.host.class == "darwin") then
                    "global:super+$=toggle_quick_terminal"
                  else
                    "global:super+$=toggle_quick_terminal"
                )
              ];
              theme = "light:Catppuccin Latte,dark:Catppuccin Mocha";
            };
          };
        };
    };
}
