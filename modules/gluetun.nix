{config, ...}: {
  virtualisation.oci-containers.containers.gluetun = {
    image = "qmcgaw/gluetun:latest";
    ports = [
      "8080:8080" # qBittorrent WebUI
    ];
    volumes = [
      "/var/lib/gluetun:/gluetun"
    ];
    environment = {
      VPN_SERVICE_PROVIDER = "protonvpn";
      VPN_TYPE = "wireguard";
      VPN_PORT_FORWARDING = "on";
      VPN_PORT_FORWARDING_UP_COMMAND = ''
        /bin/sh -c 'wget -O- --retry-connrefused --post-data "json={\"listen_port\":{{PORT}},\"current_network_interface\":\"{{VPN_INTERFACE}}\",\"random_port\":false,\"upnp\":false}" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'
      '';
      VPN_PORT_FORWARDING_DOWN_COMMAND = ''
        /bin/sh -c 'wget -O- --retry-connrefused --post-data "json={\"listen_port\":0,\"current_network_interface\":\"lo\"}" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'
      '';
      SERVER_COUNTRIES = "United States";
      PORT_FORWARD_ONLY = "on";
      TZ = config.time.timeZone;
    };
    environmentFiles = [config.age.secrets."gluetun.env".path];
    extraOptions = [
      "--cap-add=NET_ADMIN"
      "--device=/dev/net/tun:/dev/net/tun"
    ];
  };
}
