{
  my.gpg.homeManager = { pkgs, ... }: {
    home.packages = [ pkgs.pinentry-all ];
    programs.gpg.enable = true;
    services.gpg-agent.enable = true;
  };
}
