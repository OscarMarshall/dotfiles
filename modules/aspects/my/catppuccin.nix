{ inputs, ... }: {
  flake-file.inputs.catppuccin-wallpapers = {
    flake = false;
    url = "github:zhichaoh/catppuccin-wallpapers";
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
            name = "catppuccin-mocha-dark-cursors";
            package = pkgs.catppuccin-cursors.mochaDark;
            size = 24;
          };
          image = "${inputs.catppuccin-wallpapers}/os/nix-black-4k.png";
          targets.emacs.colors.enable = false;
        };
      };
    };
}
