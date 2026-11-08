{ den, ... }: {
  my.discord = { user, ... }: {
    includes = [
      (den._.unfree [
        "discord"
        "discord-unwrapped"
      ])
    ];

    homeManager = { pkgs, ... }: { home.packages = [ pkgs.discord ]; };
    # Login session + settings. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [ ".config/discord" ];
  };
}
