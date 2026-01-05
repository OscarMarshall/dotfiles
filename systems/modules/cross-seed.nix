{config, ...}: {
  services.cross-seed = {
    enable = true;
    user = "qbittorrent";
    group = "qbittorrent";
    useGenConfigDefaults = true;
    settingsFile = config.age.secrets."cross-seed.json".path;
    settings = {
      port = 2468;
      linkDirs = ["/metalminds/torrents/link-dir"];
      matchMode = "partial";
    };
  };
}
