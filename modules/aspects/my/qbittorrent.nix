{ lib, ... }:
let
  port = 8080;
  port' = toString port;
in
{
  my.qbittorrent =
    {
      administrators,
      global ? false,
    }:
    { host, ... }: {
      nixos = { config, ... }: {
        users = {
          groups.qbittorrent.gid = 985;

          users = {
            qbittorrent = {
              description = "qBittorrent service user";
              group = "qbittorrent";
              isSystemUser = true;
              uid = 985;
            };
          }
          // (lib.genAttrs administrators (user: {
            extraGroups = [ "qbittorrent" ];
          }));
        };

        virtualisation.oci-containers.containers = {
          gluetun.ports = [ "${port'}:${port'}" ];

          qbittorrent = {
            dependsOn = [ "gluetun" ];

            environment = {
              PGID = toString config.users.groups.qbittorrent.gid;
              PUID = toString config.users.users.qbittorrent.uid;
              TZ = config.time.timeZone;
              WEBUI_PORT = port';
            };

            environmentFiles = [ config.age.secrets."qbittorrent.env".path ];
            extraOptions = [ "--network=container:gluetun" ];
            image = "lscr.io/linuxserver/qbittorrent:5.1.4-r1-ls435@sha256:e0cedcadd62f809efdeddfd32e4d1192f9a74e6e64ed6753bfc6e2c3ed4a714a";

            volumes = [
              "/var/lib/qBittorrent:/config"
              "/metalminds/torrents:/metalminds/torrents"
            ];
          };
        };
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

      # No `homepage` block: deliberately not a dashboard tile, but `label`/`icon`/`group` still
      # feed its Authentik application (see virtual-host.nix).
      virtual-host = {
        inherit global port;
        group = "Arr Stack";
        host = host.name;
        icon = "https://raw.githubusercontent.com/qbittorrent/qBittorrent/master/src/icons/qbittorrent-tray.svg";
        label = "qBittorrent";
        name = "qbittorrent";
        protected = true;
      };
    };
}
