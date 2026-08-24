{ den, ... }: {
  my.discord = {
    includes = [
      (den._.unfree [
        "discord"
        "discord-unwrapped"
      ])
    ];

    darwin.homebrew.casks = [ "discord" ];
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.discord ]; };
  };
}
