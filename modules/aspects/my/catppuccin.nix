{ my, ... }:
{
  my.catppuccin =
    { flavor ? "mocha" }:
    let
      base00 = {
        latte = "eff1f5";
        frappe = "303446";
        macchiato = "24273a";
        mocha = "1e1e2e";
      }.${flavor};
    in
    {
      homeManager =
        { config, pkgs, ... }:
        {
          stylix = {
            base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-${flavor}.yaml";
            image = config.lib.stylix.pixel base00;
            targets.ghostty.enable = false;
          };

          programs.ghostty.settings.theme =
            # Use system appearance detection with Latte (light) and Mocha (dark),
            # independent of flavor, to match the system's light/dark mode preference.
            "light:Catppuccin Latte,dark:Catppuccin Mocha";
        };
    };
}
