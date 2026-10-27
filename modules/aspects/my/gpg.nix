{
  my.gpg = {
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.pinentry-all ]; };

    homeManager = {
      programs.gpg.enable = true;
      services.gpg-agent.enable = true;
    };
  };
}
