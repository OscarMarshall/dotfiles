{ inputs, ... }: {
  flake-file.inputs.catppuccin-wallpapers = {
    url = "github:zhichaoh/catppuccin-wallpapers";
    flake = false;
  };

  my.catppuccin =
    {
      flavor ? "mocha",
    }:
    {
      homeManager = { pkgs, ... }: {
        stylix = {
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-${flavor}.yaml";

          cursor = {
            package = pkgs.catppuccin-cursors.mochaDark;
            name = "catppuccin-mocha-dark-cursors";
            size = 24;
          };

          image = "${inputs.catppuccin-wallpapers}/os/nix-black-4k.png";
          targets.emacs.colors.enable = false;
        };
      };
    };
}
