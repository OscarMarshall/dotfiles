let
  gamePort = 7777;
  messagingPort = 8888;
in
{
  my.satisfactory-server = {
    dataset = {
      pool = "metalminds";
      name = "satisfactory-server";
    };

    nixos = { config, ... }: {
      users = {
        users.satisfactory-server = {
          uid = 984;
          isSystemUser = true;
          group = "satisfactory-server";
        };
        groups.satisfactory-server.gid = 984;
      };

      virtualisation.oci-containers.containers.satisfactory-server = {
        image = "wolveix/satisfactory-server:latest@sha256:e103700ae6ae4c50f19dac80eadb2a805c5b885e179ae2a40850e967bf189efd";
        ports = [
          "${toString gamePort}:${toString gamePort}/tcp"
          "${toString gamePort}:${toString gamePort}/udp"
          "${toString messagingPort}:${toString messagingPort}/tcp"
        ];
        volumes = [ "/metalminds/satisfactory-server:/config" ];
        environment = {
          PUID = toString config.users.users.satisfactory-server.uid;
          PGID = toString config.users.groups.satisfactory-server.gid;
          MAXPLAYERS = "4";
        };
      };

      networking.firewall = {
        allowedTCPPorts = [
          gamePort
          messagingPort
        ];
        allowedUDPPorts = [ gamePort ];
      };
    };
  };
}
