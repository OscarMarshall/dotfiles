{
  my.gpg = {
    homeManager = {
      programs.gpg.enable = true;
      services.gpg-agent.enable = true;
    };

    hmLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.pinentry-all ];
      };

    hmDarwin =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.pinentry_mac ];
      };
  };
}
