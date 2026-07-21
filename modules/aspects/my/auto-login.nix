{
  my.auto-login = user: {
    nixos =
      { config, lib, ... }:
      lib.mkIf config.services.displayManager.enable {
        services.displayManager.autoLogin = {
          inherit user;
          enable = true;
        };
      };
  };
}
