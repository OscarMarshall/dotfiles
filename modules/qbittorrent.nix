{config, ...}: {
  users = {
    users = {
      qbittorrent = {
        uid = 985;
        description = "qBittorrent service user";
        isSystemUser = true;
        group = "qbittorrent";
      };
      # Add radarr and sonarr users to qbittorrent group for file access
      radarr.extraGroups = ["qbittorrent"];
      sonarr.extraGroups = ["qbittorrent"];
    };
    groups.qbittorrent.gid = 985;
  };

  virtualisation.oci-containers.containers.qbittorrent = {
    image = "lscr.io/linuxserver/qbittorrent:latest";
    volumes = [
      "/var/lib/qBittorrent:/config"
      "/metalminds/torrents:/metalminds/torrents"
    ];
    environment = {
      PUID = toString config.users.users.qbittorrent.uid;
      PGID = toString config.users.groups.qbittorrent.gid;
      TZ = config.time.timeZone;
      WEBUI_PORT = "8080";
    };
    environmentFiles = [config.age.secrets."qbittorrent.env".path];
    dependsOn = ["gluetun"];
    extraOptions = [
      "--network=container:gluetun"
    ];
  };

  services.nginx.virtualHosts."qbittorrent.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:8080/";
  };
}
