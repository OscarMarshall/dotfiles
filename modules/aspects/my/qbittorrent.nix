{ inputs, lib, ... }:
let
  port = 8080;
  port' = toString port;
  namespaceAddress = "192.168.15.1";
  bridgeAddress = "192.168.15.5";
  accessibleFromSubnet = "10.10.10.0/24";
in
{
  flake-file.inputs.vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

  my.qbittorrent =
    { administrators }:
    {
      secrets =
        { secrets, ... }:
        {
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

      nixosSecrets."Harmony_P2P-US-CA-898.conf".file = ../../../secrets/Harmony_P2P-US-CA-898.conf.age;

      nixos =
        { config, pkgs, ... }:
        {
          imports = [ (inputs.vpn-confinement.nixosModules.default or { }) ];

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

          services = {
            nginx.virtualHosts."qbittorrent.harmony.silverlight-nex.us" = {
              forceSSL = true;
              enableACME = true;
              locations."/".proxyPass = "http://${namespaceAddress}:${port'}/";
            };

            qbittorrent = {
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
                    ${pkgs.curl}/bin/curl -XPOST http://${bridgeAddress}:${toString config.services.cross-seed.settings.port}/api/webhook \
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
                  Password_PBKDF2 = "@ByteArray(3+DJBBGQhl1i7uYQ4PAZAA==:FTHL6psR2VpGAUnpsh/SlTa5mPjZZ6ab6YwkzqH0JxUL94iDPCKHFpkZQoAqnlv/0rri76zKo6on73kwI3s7dA==)";
                  ReverseProxySupportEnabled = true;
                  TrustedReverseProxiesList = "qbittorrent.harmony.silverlight-nex.us";
                  Username = "oscar";
                };
              };
            };
          };

          systemd.services.qbittorrent = {
            serviceConfig.EnvironmentFile = [ config.age.secrets."qbittorrent.env".path ];
            vpnConfinement = {
              enable = true;
              vpnNamespace = "proton0";
            };
          };

          vpnNamespaces.proton0 = {
            enable = true;
            wireguardConfigFile = config.age.secrets."Harmony_P2P-US-CA-898.conf".path;
            accessibleFrom = [ accessibleFromSubnet ];
            portMappings = [
              {
                from = port;
                to = port;
              }
            ];
          };
        };
    };
}
