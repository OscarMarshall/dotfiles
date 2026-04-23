{
  my.doc-browser = {
    darwin.homebrew.casks = [ "dash" ];

    hmLinux =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.zeal ];
      };
  };
}
