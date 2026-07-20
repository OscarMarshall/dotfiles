{
  my.nh.homeManager.programs.nh = {
    enable = true;

    clean = {
      enable = true;
      extraArgs = "--keep-since 7d";
    };

    flake = "github:OscarMarshall/dotfiles";
  };
}
