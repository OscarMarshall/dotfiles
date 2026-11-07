{ den, ... }: {
  my.steam = { user, ... }: {
    includes = [
      (den._.unfree [
        "steam"
        "steam-unwrapped"
      ])
    ];

    nixos.programs.steam.enable = true;

    # The Steam client and installed games - large. `preserve` (modules/aspects/my/preserve.nix) is
    # inert without my.preservation.
    preserve.users.${user.userName}.directories = [
      ".local/share/Steam"
      ".steam"
    ];
  };
}
