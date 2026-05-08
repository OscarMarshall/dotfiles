{ my, ... }:
let
  port = 8080;
  crossSeedPort = 2468;
  namespaceAddress = "192.168.15.1";
  bridgeAddress = "192.168.15.5";
in
{
  my.qbittorrent =
    { administrators }:
    {
      includes = [
        (my.nginx._.virtual-host "qbittorrent.harmony.silverlight-nex.us" {
          host = namespaceAddress;
          port = port;
        })
      ];

      secrets =
        { secrets, ... }:
        {
          "qbittorrent-password-pbkdf2".generator = {
            dependencies = { inherit (secrets) oscar-password; };
            script =
              {
                lib,
                pkgs,
                decrypt,
                deps,
                ...
              }:
              ''
                PASSWORD="$(${decrypt} ${lib.escapeShellArg deps.oscar-password.file})"

                PASSWORD="$PASSWORD" ${pkgs.python3}/bin/python - <<'PY'
                import base64
                import hashlib
                import os

                password = os.environ["PASSWORD"].encode()
                salt = os.urandom(16)
                digest = hashlib.pbkdf2_hmac("sha512", password, salt, 100000, 64)
                print(f"@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(digest).decode()})")
                PY
              '';
          };

          "qbittorrent.env".generator = {
            dependencies = { inherit (secrets) cross-seed-api-key qbittorrent-password-pbkdf2; };
            script =
              {
                lib,
                decrypt,
                deps,
                ...
              }:
              ''
                printf 'CROSS_SEED_API_KEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps."cross-seed-api-key".file})"
                printf 'QBITTORRENT_PASSWORD_PBKDF2="%s"\n' "$(${decrypt} ${
                  lib.escapeShellArg deps."qbittorrent-password-pbkdf2".file
                })"
              '';
          };
        };

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
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

          services.qbittorrent = {
            enable = true;
            package = pkgs.qbittorrent-nox;
            webuiPort = port;
            user = "qbittorrent";
            group = "qbittorrent";
            profileDir = "/var/lib/qBittorrent";
            serverConfig = {
              AutoRun = {
                enabled = true;
                program = ''
                  ${pkgs.curl}/bin/curl -XPOST http://${bridgeAddress}:${toString crossSeedPort}/api/webhook \
                    -H "X-Api-Key: $CROSS_SEED_API_KEY" \
                    -d "infoHash=%I" \
                    -d "includeSingleEpisodes=true"
                '';
              };
              BitTorrent.Session = {
                DefaultSavePath = "/metalminds/torrents/downloads";
                IgnoreSlowTorrentsForQueueing = true;
                MaxActiveTorrents = 999999999;
                MaxActiveUploads = 999999999;
                Tags = "cross-seed";
              };
              Preferences.WebUI = {
                ReverseProxySupportEnabled = true;
                TrustedReverseProxiesList = "qbittorrent.harmony.silverlight-nex.us";
                Username = "oscar";
              };
            };
          };

          systemd.services.qbittorrent = {
            serviceConfig = {
              EnvironmentFile = [ config.age.secrets."qbittorrent.env".path ];
              ExecStartPre = lib.mkAfter [
                ''
                  # qBittorrent writes config under ${config.services.qbittorrent.profileDir}/qBittorrent/config/
                  config_file="${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf"
                  password_pbkdf2="$(
                    (
                      set -a
                      . ${config.age.secrets."qbittorrent.env".path}
                      printf '%s' "$QBITTORRENT_PASSWORD_PBKDF2"
                    )
                  )"

                  if ${pkgs.gnugrep}/bin/grep -q 'Password_PBKDF2=' "$config_file"; then
                    ${pkgs.gnused}/bin/sed -i "s|Password_PBKDF2=.*|Password_PBKDF2=$password_pbkdf2|" "$config_file"
                  else
                    if ! ${pkgs.gnugrep}/bin/grep -q '^WebUI\\Username=' "$config_file"; then
                      echo "Expected WebUI\\Username entry in $config_file before setting Password_PBKDF2" >&2
                      exit 1
                    fi

                    ${pkgs.gnused}/bin/sed -i "/^WebUI\\\\Username=/a WebUI\\\\Password_PBKDF2=$password_pbkdf2" "$config_file"
                  fi
                ''
              ];
            };
          };
        };
    };
}
