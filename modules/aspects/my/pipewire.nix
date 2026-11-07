{
  my.pipewire = {
    # WirePlumber's per-device volume/routing. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    includes = [ ({ user, ... }: { preserve.users.${user.userName}.directories = [ ".local/state/wireplumber" ]; }) ];

    nixos = {
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;

        alsa = {
          enable = true;
          support32Bit = true;
        };

        pulse.enable = true;
      };
    };
  };
}
