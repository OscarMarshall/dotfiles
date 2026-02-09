{ den, oscarmarshall, ... }:
{
  den.aspects.adelline = {
    includes = with oscarmarshall; [
      den._.primary-user
      (den._.user-shell "fish")
      # (den._.unfree [ "google-chrome" ])
      discord
      ghostty
      steam
      zen-browser
    ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          google-chrome
          inkscape
          krita
          prismlauncher
          rnote
        ];

        programs = {
          direnv.enable = true;
          fish.enable = true;
          git.enable = true;
          starship.enable = true;
        };
      };
  };
}
