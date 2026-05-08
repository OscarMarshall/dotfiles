{ my, ... }:
let
  port = 8080;
  crossSeedPort = 2468;
  namespace = "proton0";
in
{
  my.qbittorrent =
    { administrators }:
    {
      includes = [
        my."vpn-confinement"
        (my."vpn-confinement"._.service "qbittorrent")
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
                umask 077
                salt_file="$(${pkgs.coreutils}/bin/mktemp)"
                trap '${pkgs.coreutils}/bin/rm -f "$salt_file"' EXIT
                ${pkgs.openssl}/bin/openssl rand 16 > "$salt_file"
                salt_hex="$(${pkgs.coreutils}/bin/od -An -tx1 -v "$salt_file" | ${pkgs.coreutils}/bin/tr -d ' \n')"

                salt_b64="$(${pkgs.coreutils}/bin/base64 -w0 "$salt_file")"
                digest_b64="$(printf '%s' "$PASSWORD" | ${pkgs.openssl}/bin/openssl kdf -binary -keylen 64 -digest SHA512 \
                  -kdfopt pass:stdin \
                  -kdfopt hexsalt:"$salt_hex" \
                  -kdfopt iter:100000 PBKDF2 | ${pkgs.coreutils}/bin/base64 -w0)"

                printf '@ByteArray(%s:%s)\n' "$salt_b64" "$digest_b64"
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

      nixosSecrets."Harmony_P2P-US-CA-898.conf".file = ../../../secrets/Harmony_P2P-US-CA-898.conf.age;

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        lib.mkMerge [
          (my.nginx._.virtual-host "qbittorrent.harmony.silverlight-nex.us" {
            host = config.vpnNamespaces.${namespace}.namespaceAddress;
            port = config.services.qbittorrent.webuiPort;
          }).nixos
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
                    ${pkgs.curl}/bin/curl -XPOST http://${
                      config.vpnNamespaces.${namespace}.bridgeAddress
                    }:${toString crossSeedPort}/api/webhook \
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
                    password_pbkdf2="$(${pkgs.gnugrep}/bin/grep '^QBITTORRENT_PASSWORD_PBKDF2=' ${
                      config.age.secrets."qbittorrent.env".path
                    } | ${pkgs.coreutils}/bin/cut -d= -f2- | ${pkgs.gnused}/bin/sed 's/^\"//; s/\"$//')"
                    if [ -z "$password_pbkdf2" ]; then
                      echo "QBITTORRENT_PASSWORD_PBKDF2 is empty or missing in ${config.age.secrets."qbittorrent.env".path}" >&2
                      exit 1
                    fi

                    if ${pkgs.gnugrep}/bin/grep -q 'Password_PBKDF2=' "$config_file"; then
                      ${pkgs.gnused}/bin/sed -i "s|Password_PBKDF2=.*|Password_PBKDF2=$password_pbkdf2|" "$config_file"
                    else
                      if ! ${pkgs.gnugrep}/bin/grep -Fq 'WebUI\\Username=' "$config_file"; then
                        echo "Unable to locate WebUI\\Username in $config_file" >&2
                        exit 1
                      fi

                      ${pkgs.gnused}/bin/sed -i "/^WebUI\\\\Username=/a WebUI\\\\Password_PBKDF2=$password_pbkdf2" "$config_file"

                      if ! ${pkgs.gnugrep}/bin/grep -q 'Password_PBKDF2=' "$config_file"; then
                        echo "Unable to add Password_PBKDF2 to $config_file" >&2
                        exit 1
                      fi
                    fi
                  ''
                ];
              };
            };

            vpnNamespaces.${namespace} = {
              enable = true;
              wireguardConfigFile = config.age.secrets."Harmony_P2P-US-CA-898.conf".path;
              accessibleFrom = [ "10.10.10.0/24" ];
              portMappings = [
                {
                  from = config.services.qbittorrent.webuiPort;
                  to = config.services.qbittorrent.webuiPort;
                }
              ];
            };
          }
        ];
    };
}
