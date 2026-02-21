let
  hosts = {
    "tracker.bakabt.me" = "193.46.255.135";
  };
in
{
  my.gluetun.nixos =
    { config, ... }:
    {
      virtualisation.oci-containers.containers.gluetun = {
        image = "qmcgaw/gluetun:v3.41.1@sha256:1a5bf4b4820a879cdf8d93d7ef0d2d963af56670c9ebff8981860b6804ebc8ab";
        volumes = [ "/var/lib/gluetun:/gluetun" ];
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
        environmentFiles = [ config.age.secrets."gluetun.env".path ];
        extraOptions = [
          "--add-host=tracker.bakabt.me:193.46.255.135"
          "--cap-add=NET_ADMIN"
          "--device=/dev/net/tun:/dev/net/tun"
        ]
        ++ builtins.attrValues (builtins.mapAttrs (host: ip: "--add-host=${host}:${ip}") hosts);
      };
    };
}
