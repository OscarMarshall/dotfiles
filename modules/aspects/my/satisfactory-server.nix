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
        # See bookshelf.nix's comment on readarr's own pinned id for why 31001 (rather than a
        # number under 1000, which is what this used to be pinned to and how it collided with both
        # nix-minecraft's dynamically-allocated `minecraft` group and the unrelated `mandb` system
        # user).
        groups.satisfactory-server.gid = 31001;

        users.satisfactory-server = {
          group = "satisfactory-server";
          isSystemUser = true;
          uid = 31001;
        };
      };

      virtualisation.oci-containers.containers.satisfactory-server = {
        environment = {
          MAXPLAYERS = "4";
          PGID = toString config.users.groups.satisfactory-server.gid;
          PUID = toString config.users.users.satisfactory-server.uid;
        };

        image = "wolveix/satisfactory-server:latest@sha256:ca895e72c78a586c4b9f50774a852f53915dc7299977af5ba26978607fad9213";

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
