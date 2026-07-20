{
  my.networkmanager.includes = [
      ({ user, ... }: { nixos.users.users.${user.userName}.extraGroups = [ "networkmanager" ]; })
      { nixos.networking.networkmanager.enable = true; }
    ];
}
