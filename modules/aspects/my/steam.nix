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
    # The same, for when a user includes my.steam rather than the host (tensoon via oscar): a user
    # aspect's bare `nixos` stays with the user (den#694), so deliver it to the user's hosts
    # explicitly (den.batteries.mutual-provider, included in modules/aspects/defaults.nix).
    provides.to-hosts.nixos.programs.steam.enable = true;
  };
}
