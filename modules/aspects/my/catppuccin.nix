{ inputs, ... }:
{
  flake-file.inputs.catppuccin-wallpapers = {
    url = "github:zhichaoh/catppuccin-wallpapers";
    flake = false;
  };

  my.catppuccin =
    {
      flavor ? "mocha",
    }:
    {
      homeManager =
        { pkgs, ... }:
        {
          stylix = {
            base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-${flavor}.yaml";
            image = "${inputs.catppuccin-wallpapers}/os/nix-black-4k.png";
            targets.emacs.colors.enable = false;
            targets.ghostty.colors.enable = false;
          };

          programs = {
            emacs.extraConfig = ''
              (setq doom-theme 'catppuccin)
              (add-hook 'ns-system-appearance-change-functions
                        (lambda (appearance)
                          "Load theme, taking current system APPEARANCE into consideration."
                          (setq catppuccin-flavor (pcase appearance
                                                    ('light 'latte)
                                                    ('dark 'mocha)))
                          (catppuccin-reload)))
            '';
            ghostty.settings.theme =
              # Use system appearance detection with Latte (light) and Mocha (dark),
              # independent of flavor, to match the system's light/dark mode preference.
              "light:Catppuccin Latte,dark:Catppuccin Mocha";
          };
        };
    };
}
