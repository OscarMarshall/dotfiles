{ lib, ... }:
let
  port = 8080;
  port' = toString port;
in
{
  my.qbittorrent = { administrators }: {
    virtual-host = {
      name = "qbittorrent";
      url = "qbittorrent.harmony.silverlight-nex.us";
      protected = true;
      inherit port;
    };

    secrets = { secrets, ... }: {
      "qbittorrent.env".generator = {
        dependencies = { inherit (secrets) cross-seed-api-key; };
        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'CROSS_SEED_API_KEY=%s\n' "$(${decrypt} ${lib.escapeShellArg deps."cross-seed-api-key".file})"
          '';
      };
    };

    nixos = { config, ... }: {
      users = {
        users = {
          qbittorrent = {
            uid = 985;
            description = "qBittorrent service user";
            isSystemUser = true;
            group = "qbittorrent";
          };
        }
        // (lib.genAttrs administrators (user: {
          extraGroups = [ "qbittorrent" ];
        }));

        groups.qbittorrent.gid = 985;
      };

      virtualisation.oci-containers.containers = {
        gluetun.ports = [ "${port'}:${port'}" ];
        qbittorrent = {
          image = "lscr.io/linuxserver/qbittorrent:5.1.4-r1-ls435@sha256:e0cedcadd62f809efdeddfd32e4d1192f9a74e6e64ed6753bfc6e2c3ed4a714a";
          volumes = [
            "/var/lib/qBittorrent:/config"
            "/metalminds/torrents:/metalminds/torrents"
          ];
          environment = {
            PUID = toString config.users.users.qbittorrent.uid;
            PGID = toString config.users.groups.qbittorrent.gid;
            TZ = config.time.timeZone;
            WEBUI_PORT = port';
          };
          environmentFiles = [ config.age.secrets."qbittorrent.env".path ];
          dependsOn = [ "gluetun" ];
          extraOptions = [ "--network=container:gluetun" ];
        };
      };
    };
  };
}
