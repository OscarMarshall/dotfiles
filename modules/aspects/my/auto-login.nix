{
  my.auto-login = user: {
    nixos =
      { config, lib, ... }:
      lib.mkIf config.services.displayManager.enable {
        services.displayManager.autoLogin = {
          enable = true;
          inherit user;
        };
      };
  };
}
