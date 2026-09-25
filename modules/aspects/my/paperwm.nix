{
  my.paperwm = {
    darwin.homebrew.casks = [ "hammerspoon" ];

    hmDarwin =
      { pkgs, ... }:
      let
        # Pinned to upstream's own "release" branch (the one their README tells SpoonInstall users
        # to track), not "main" - main gets experimental branches merged straight to it.
        spoon = pkgs.fetchFromGitHub {
          hash = "sha256-gII1uCqVUo3oNTzxzTPrstw7sDJdSjhKTqFEelE5LjM=";
          owner = "mogenson";
          repo = "PaperWM.spoon";
          rev = "d0e8149466a5e99560a97d9da58bc310075d28f6";
        };
      in
      {
        home.file = {
          ".hammerspoon/Spoons/PaperWM.spoon".source = spoon;

          ".hammerspoon/init.lua".text = ''
            PaperWM = hs.loadSpoon("PaperWM")
            PaperWM:bindHotkeys(PaperWM.default_hotkeys)
            PaperWM:start()
          '';
        };
      };
  };
}
