{
  my.networkmanager = {
    includes = [
      { nixos.networking.networkmanager.enable = true; }
      (
        { user, ... }:
        {
          nixos.users.users.${user.userName}.extraGroups = [ "networkmanager" ];
        }
      )
    ];
  };
}
