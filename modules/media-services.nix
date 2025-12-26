{config, ...}: {
  services = {
    autobrr = {
      enable = true;
      secretFile = config.age.secrets.autobrr-secret.path;
      settings = {
        checkForUpdates = true;
        host = "127.0.0.1";
        port = 7474;
      };
    };
    cross-seed = {
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
    flaresolverr.enable = true;
    plex = {
      enable = true;
      openFirewall = true;
    };
    prowlarr.enable = true;
    radarr.enable = true;
    sonarr.enable = true;
  };

  services.nginx.virtualHosts = {
    "autobrr.harmony.silverlight-nex.us" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString config.services.autobrr.settings.port}/";
    };
    "plex.harmony.silverlight-nex.us" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:32400/";
    };
    "prowlarr.harmony.silverlight-nex.us" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString config.services.prowlarr.settings.server.port}/";
    };
    "radarr.harmony.silverlight-nex.us" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString config.services.radarr.settings.server.port}/";
    };
    "sonarr.harmony.silverlight-nex.us" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString config.services.sonarr.settings.server.port}/";
    };
  };
}
