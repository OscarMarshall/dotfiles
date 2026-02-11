{
  oscarmarshall.auto-login = user: {
    homeManager = {
      dconf = {
        enable = true;
        settings."org/gnome/desktop/screensaver".lock-enabled = false;
      };
    };

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
