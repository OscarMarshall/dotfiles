{
  my.gpg = {
    hmDarwin = { pkgs, ... }: { home.packages = [ pkgs.pinentry_mac ]; };
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.pinentry-all ]; };

    homeManager = {
      programs.gpg.enable = true;
      services.gpg-agent.enable = true;
    };
  };
}
