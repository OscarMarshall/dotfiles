{
  my.nh.homeManager = {
    home.sessionVariables.NH_SHOW_ACTIVATION_LOGS = "1";

    programs.nh = {
      enable = true;

      clean = {
        enable = true;
        extraArgs = "--keep-since 7d";
      };

      flake = "github:OscarMarshall/dotfiles";
    };
  };
}
