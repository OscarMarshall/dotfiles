{ den, ... }:
{
  oscarmarshall.networkmanager = den.lib.parametric.atLeast {
    includes = [
      { includes = [ ]; nixos.networking.networkmanager.enable = true; }
      (
        { user, ... }:
        {
          includes = [ ];
          nixos.users.users.${user.username}.extraGroups = [ "networkmanager" ];
        }
      )
    ];
  };
}
