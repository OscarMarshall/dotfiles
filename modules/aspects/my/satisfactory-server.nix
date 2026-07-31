let
  gamePort = 7777;
  messagingPort = 8888;
in
{
  my.satisfactory-server = {
    dataset = {
      # Owned by the same dedicated `satisfactory-server` user/group declared below (matching the
      # container's own PUID/PGID) - zfs.nix's generic `dataset`-quirk consumer chowns it once
      # created, and `units` orders this container after that.
      group = "satisfactory-server";
      name = "satisfactory-server";
      pool = "metalminds";
      units = [ "podman-satisfactory-server" ];
      user = "satisfactory-server";
    };

    nixos = { config, ... }: {
      networking.firewall = {
        allowedTCPPorts = [
          gamePort
          messagingPort
        ];

        allowedUDPPorts = [ gamePort ];
      };

      users = {
        groups.satisfactory-server.gid = 984;

        users.satisfactory-server = {
          group = "satisfactory-server";
          isSystemUser = true;
          uid = 984;
        };
      };

      virtualisation.oci-containers.containers.satisfactory-server = {
        environment = {
          MAXPLAYERS = "4";
          PGID = toString config.users.groups.satisfactory-server.gid;
          PUID = toString config.users.users.satisfactory-server.uid;
        };

        image = "wolveix/satisfactory-server:latest@sha256:e103700ae6ae4c50f19dac80eadb2a805c5b885e179ae2a40850e967bf189efd";

        ports = [
          "${toString gamePort}:${toString gamePort}/tcp"
          "${toString gamePort}:${toString gamePort}/udp"
          "${toString messagingPort}:${toString messagingPort}/tcp"
        ];

        volumes = [ "/metalminds/satisfactory-server:/config" ];
      };
    };
  };
}
