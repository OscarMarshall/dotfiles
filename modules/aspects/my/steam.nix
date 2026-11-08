{ den, ... }: {
  my.steam = {
    includes = [
      (den._.unfree [
        "steam"
        "steam-unwrapped"
      ])
      # The Steam client and installed games - large. Via `includes` because my.steam is also
      # included at host scope (melaan), where there is no `user`. `preserve`
      # (modules/aspects/my/preserve.nix) is inert without my.preservation.
      ({ user, ... }: {
        preserve.users.${user.userName}.directories = [
          ".local/share/Steam"
          ".steam"
        ];
      })
    ];

    nixos.programs.steam.enable = true;
  };
}
