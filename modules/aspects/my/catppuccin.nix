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
            cursor = {
              name = "catppuccin-mocha-dark-cursors";
              package = pkgs.catppuccin-cursors.mochaDark;
              size = 24;
            };
          };
        };
    };
}
