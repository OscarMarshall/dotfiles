{
  oscarmarshall.disable-gnome-lockscreen.homeManager = {
    dconf = {
      enable = true;
      settings."org/gnome/desktop/screensaver".lock-enabled = false;
    };
  };
}
