{
  my.gpg =
    { host, ... }:
    {
      homeManager =
        { pkgs, ... }:
        {
          home.packages = with pkgs; if host.class == "darwin" then [ pinentry_mac ] else [ pinentry-all ];
          programs.gpg.enable = true;
          services.gpg-agent.enable = true;
        };
    };
}
