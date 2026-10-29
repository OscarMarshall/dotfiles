{ den, ... }: {
  my.steam = {
    includes = [
      (den._.unfree [
        "steam"
        "steam-unwrapped"
      ])
    ];

    nixos.programs.steam.enable = true;
  };
}
