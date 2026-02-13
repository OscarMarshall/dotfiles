{ den, ... }:
{
  my.networkmanager = den.lib.parametric.atLeast {
    includes = [
      { nixos.networking.networkmanager.enable = true; }
      (
        { user, ... }:
        {
          nixos.users.users.${user.username}.extraGroups = [ "networkmanager" ];
        }
      )
    ];
  };
}
