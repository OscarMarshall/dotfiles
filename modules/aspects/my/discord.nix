{ den, ... }: {
  my.discord = {
    includes = [
      (den._.unfree [
        "discord"
        "discord-unwrapped"
      ])
    ];

    homeManager = { pkgs, ... }: { home.packages = [ pkgs.discord ]; };
  };
}
