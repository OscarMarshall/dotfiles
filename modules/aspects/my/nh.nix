{
  my.nh.homeManager.programs.nh = {
    enable = true;
    flake = "github:OscarMarshall/dotfiles";
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d";
    };
  };
}
