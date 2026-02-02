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
            };
          };
        };
    };
}
