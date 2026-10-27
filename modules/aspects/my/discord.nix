{ den, ... }: {
  my.discord = {
    includes = [
      (den._.unfree [
        "discord"
        "discord-unwrapped"
      ])
    ];

    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.discord ]; };
  };
}
