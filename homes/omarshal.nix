{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  oscarConfig = import ./oscar.nix {inherit config lib osConfig pkgs;};
in
  lib.recursiveUpdate oscarConfig {
    home = {
      username = "omarshal";
      sessionVariables = {
        ITERM2_SQUELCH_MARK = 1;
      };
      packages = [
        # Darwin-specific packages not in oscar.nix
      ];
    };

    imports = [inputs.zen-browser.homeModules.twilight];

    programs = {
      java.enable = true;
      rbenv.enable = true;
      zsh.envExtra = lib.mkAfter ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      '';
    };
  }

