{ config, ... }:

{
  vpnNamespaces.proton0 = {
    enable = true;
    wireguardConfigFile = config.age.secrets."Harmony_P2P-US-CA-898.conf".path;
    accessibleFrom = [ "10.10.10.0/24" ];
    portMappings = [
      # Autobrr
      {
        from = config.services.autobrr.settings.port;
        to = config.services.autobrr.settings.port;
      }
      # Prowlarr
      {
        from = config.services.prowlarr.settings.server.port;
        to = config.services.prowlarr.settings.server.port;
      }
      # qBittorrent
      {
        from = config.services.qbittorrent.webuiPort;
        to = config.services.qbittorrent.webuiPort;
      }
      # Radarr
      {
        from = config.services.radarr.settings.server.port;
        to = config.services.radarr.settings.server.port;
      }
      # Sonarr
      {
        from = config.services.sonarr.settings.server.port;
        to = config.services.sonarr.settings.server.port;
      }
    ];
  };
}
