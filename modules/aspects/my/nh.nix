{
  my.nh.homeManager.programs.nh = {
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d";
    };
    enable = true;
    flake = "github:OscarMarshall/dotfiles";
  };
}
