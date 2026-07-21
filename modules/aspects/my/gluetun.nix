{
  my.gluetun = {
    nixos = { config, ... }: {
      virtualisation.oci-containers.containers.gluetun = {
        environment = {
          PORT_FORWARD_ONLY = "on";
          SERVER_COUNTRIES = "United States";
          TZ = config.time.timeZone;
          VPN_PORT_FORWARDING = "on";

          VPN_PORT_FORWARDING_DOWN_COMMAND = ''
            /bin/sh -c 'wget -O- --retry-connrefused --post-data "json={\"listen_port\":0,\"current_network_interface\":\"lo\"}" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'
          '';

          VPN_PORT_FORWARDING_UP_COMMAND = ''
            /bin/sh -c 'wget -O- --retry-connrefused --post-data "json={\"listen_port\":{{PORT}},\"current_network_interface\":\"{{VPN_INTERFACE}}\",\"random_port\":false,\"upnp\":false}" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'
          '';

          VPN_SERVICE_PROVIDER = "protonvpn";
          VPN_TYPE = "wireguard";
        };

        environmentFiles = [ config.age.secrets."gluetun.env".path ];

        extraOptions = [
          "--cap-add=NET_ADMIN"
          "--device=/dev/net/tun:/dev/net/tun"
        ];

        image = "qmcgaw/gluetun:v3.41.1@sha256:1a5bf4b4820a879cdf8d93d7ef0d2d963af56670c9ebff8981860b6804ebc8ab";
        volumes = [ "/var/lib/gluetun:/gluetun" ];
      };
    };

    secrets = { secrets, ... }: {
      "gluetun.env".generator = {
        dependencies = { inherit (secrets) proton-vpn-wireguard-private-key; };

        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'WIREGUARD_PRIVATE_KEY="%s"\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.proton-vpn-wireguard-private-key.file}
            )"
          '';
      };

      proton-vpn-wireguard-private-key = {
        intermediary = true;
        rekeyFile = ../../../secrets/proton-vpn-wireguard-private-key.age;
      };
    };
  };
}
