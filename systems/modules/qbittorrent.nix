{config, ...}: {
  users = {
    users = {
      qbittorrent = {
        uid = 985;
        description = "qBittorrent service user";
        isSystemUser = true;
        group = "qbittorrent";
      };
      # Add oscar to qbittorrent group for managing torrents
      oscar.extraGroups = ["qbittorrent"];
      # Add radarr and sonarr users to qbittorrent group for file access
      radarr.extraGroups = ["qbittorrent"];
      sonarr.extraGroups = ["qbittorrent"];
    };
    groups.qbittorrent.gid = 985;
  };

  virtualisation.oci-containers.containers.qbittorrent = {
    image = "lscr.io/linuxserver/qbittorrent:5.1.4-r1-ls435@sha256:e0cedcadd62f809efdeddfd32e4d1192f9a74e6e64ed6753bfc6e2c3ed4a714a";
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
