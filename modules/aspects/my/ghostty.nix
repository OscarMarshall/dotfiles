{ den, lib, ... }:
{
  my.ghostty = den.lib.parametric {
    includes = [
      (
        { host, ... }:
        {
          homeManager =
            { pkgs, ... }:
            {
              programs.ghostty = lib.mkIf (host.class == "darwin") {
                package = pkgs.ghostty-bin;
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
        keybind = [ "global:super+Backquote=toggle_quick_terminal" ];
      };
    };
  };
}
