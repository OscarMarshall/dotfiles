let
  crossSeedPort = 2468;
  namespace = "proton0";
  # Pinned explicitly (rather than left at VPN-Confinement's own default) so this value can be
  # referenced here for the `virtual-host` upstream, without needing `config` in a scope that
  # doesn't have it.
  namespaceAddress = "192.168.15.1";
  port = 8080;
  # ProtonVPN's fixed NAT-PMP gateway address inside the WireGuard tunnel itself - same for every
  # ProtonVPN WireGuard config, unrelated to `namespaceAddress` above (which is VPN-Confinement's
  # own bridge address for reaching *into* the namespace from outside it).
  protonGatewayAddress = "10.2.0.1";
  # VPN-Confinement's own naming convention for the WireGuard interface it creates inside the
  # namespace (see its vpn-up.nix: `ip link add ${netnsName}0 type wireguard`).
  wgInterface = "${namespace}0";
in
{
  my.qbittorrent =
    {
      administrators,
      global ? false,
    }:
    { host, ... }: {
      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          services.qbittorrent = {
            enable = true;
            package = pkgs.qbittorrent-nox;
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
                # Carried over from the gluetun setup's 20-day seed cap (GlobalMaxSeedingMinutes)
                # paired with stopping rather than removing the torrent once it's hit.
                GlobalMaxSeedingMinutes = 28800;
                IgnoreSlowTorrentsForQueueing = true;
                # Same kill-switch intent as the old setup's `Interface=tun0` (gluetun's tunnel
                # interface) - updated to VPN-Confinement's WireGuard interface name. Redundant with
                # the namespace's own netns-level routing/firewall (nothing else exists to bind to
                # in there but `lo` and this), but cheap defense in depth.
                Interface = wgInterface;
                InterfaceName = wgInterface;
                MaxActiveTorrents = 999999999;
                MaxActiveUploads = 999999999;
                ShareLimitAction = "Stop";
                Tags = "cross-seed";
              };

              FileLogger = {
                Age = 1;
                AgeType = 1;
                Backup = true;
                DeleteOld = true;
                Enabled = true;
                MaxSizeBytes = 66560;
                Path = "${config.services.qbittorrent.profileDir}/qBittorrent/logs";
              };

              Network = {
                # qBittorrent's own built-in UPnP/NAT-PMP client, off before (gluetun did its own
                # port forwarding externally) and needs to stay off now for the same reason:
                # qbittorrent-portforward already negotiates and pushes the port from outside, and
                # having both running would fight each other.
                PortForwardingEnabled = false;
              };

              Preferences.WebUI = {
                # Only the addresses nginx's `protected` (Authentik forward-auth) vhost and
                # qbittorrent-portforward actually connect from - NOT `accessibleFrom` above, which
                # would let any other device on that LAN reach the WebUI directly, bypassing both
                # Authentik and qBittorrent's own (deliberately absent, see below) login.
                #   127.0.0.1/::1 - qbittorrent-portforward, confined to this same namespace
                #   192.168.15.0/24 - nginx, connecting from the veth/bridge pair (namespaceAddress/
                #     bridgeAddress) in the default namespace
                AuthSubnetWhitelist = "127.0.0.1/32,::1/128,192.168.15.0/24";
                # qBittorrent's own login is redundant for the whitelisted addresses above (already
                # authenticated by Authentik, or trusted internal automation), so skip it entirely
                # there rather than maintaining a separate Password_PBKDF2 - anything else still hits
                # a real login prompt it has no valid credentials for.
                AuthSubnetWhitelistEnabled = true;
                # `ServerDomains` below only has any effect while this is enabled - turned off
                # because nginx's forwarded Host header didn't reliably satisfy it in practice
                # (qBittorrent's own "Invalid Host header" / blank-page behavior when it doesn't
                # match exactly). `AuthSubnetWhitelist` above is the real access control here
                # anyway; this was only ever defense in depth.
                HostHeaderValidation = false;
                ReverseProxySupportEnabled = true;
                # Host-header allowlist for the WebUI itself - narrows it to the one hostname it's
                # actually reverse-proxied at. Currently inert (see `HostHeaderValidation` above),
                # kept declared for whenever that gets sorted out.
                ServerDomains = "qbittorrent.${host.name}.silverlight-nex.us";
                TrustedReverseProxiesList = "qbittorrent.${host.name}.silverlight-nex.us";
                Username = "oscar";
              };
            };

            user = "qbittorrent";
            webuiPort = port;
          };

          systemd = {
            services = {
              qbittorrent.serviceConfig.EnvironmentFile = [ config.age.secrets."qbittorrent.env".path ];

              # gluetun used to sync qBittorrent's listening port to ProtonVPN's NAT-PMP forwarded
              # port automatically; VPN-Confinement has no equivalent, so this replicates it. Runs
              # confined to the same namespace as qBittorrent itself (see `vpn-confinement` above), so
              # it reaches both the WireGuard gateway and qBittorrent's WebUI directly.
              qbittorrent-portforward = {
                description = "Sync qBittorrent's listening port with ProtonVPN's NAT-PMP forwarded port";
                after = [ "qbittorrent.service" ];
                bindsTo = [ "qbittorrent.service" ];

                serviceConfig = {
                  # The namespace's own firewall (set up by VPN-Confinement) defaults to INPUT DROP and
                  # only auto-opens the static ports declared via `portMappings`/`openVPNPorts` - it has
                  # no way to know about a port ProtonVPN assigns dynamically at runtime. Opening it here
                  # (below) needs CAP_NET_ADMIN despite running as the unprivileged `qbittorrent` user.
                  AmbientCapabilities = [ "CAP_NET_ADMIN" ];
                  CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];

                  ExecStart = ''
                    mapped_port=""
                    for protocol in udp tcp; do
                      output="$(${pkgs.libnatpmp}/bin/natpmpc -g ${protonGatewayAddress} -a 1 0 "$protocol" 60)"
                      mapped="$(printf '%s\n' "$output" | ${pkgs.gnugrep}/bin/grep -oE 'Mapped public port [0-9]+' | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+')"
                      if [ -z "$mapped" ]; then
                        echo "natpmpc did not return a mapped $protocol port from ${protonGatewayAddress}" >&2
                        exit 1
                      fi
                      if [ -z "$mapped_port" ]; then
                        mapped_port="$mapped"
                      elif [ "$mapped_port" != "$mapped" ]; then
                        echo "NAT-PMP returned different ports for udp and tcp: $mapped_port vs $mapped" >&2
                        exit 1
                      fi
                    done

                    # (Re)point a dedicated chain at the current mapped port, rather than tracking the
                    # previous port ourselves - idempotent across repeated runs and self-healing if the
                    # namespace (and thus this chain) gets torn down and recreated.
                    if ! ${pkgs.iptables}/bin/iptables -C INPUT -i ${wgInterface} -j qbittorrent-portforward 2>/dev/null; then
                      ${pkgs.iptables}/bin/iptables -N qbittorrent-portforward 2>/dev/null || true
                      ${pkgs.iptables}/bin/iptables -I INPUT 1 -i ${wgInterface} -j qbittorrent-portforward
                    fi
                    ${pkgs.iptables}/bin/iptables -F qbittorrent-portforward
                    ${pkgs.iptables}/bin/iptables -A qbittorrent-portforward -p tcp --dport "$mapped_port" -j ACCEPT
                    ${pkgs.iptables}/bin/iptables -A qbittorrent-portforward -p udp --dport "$mapped_port" -j ACCEPT

                    # No auth needed - AuthSubnetWhitelist above covers this namespace's own
                    # loopback, which is what this connects from.
                    current_port="$(${pkgs.curl}/bin/curl -fsS "http://127.0.0.1:${toString port}/api/v2/app/preferences" \
                      | ${pkgs.jq}/bin/jq -r '.listen_port')"

                    if [ "$current_port" != "$mapped_port" ]; then
                      if ${pkgs.curl}/bin/curl -fsS "http://127.0.0.1:${toString port}/api/v2/app/setPreferences" \
                          --data-urlencode "json={\"listen_port\":$mapped_port,\"random_port\":false}" >/dev/null; then
                        echo "Updated qBittorrent's listen port to $mapped_port (was $current_port)"
                      else
                        echo "Failed to update qBittorrent's listen port to $mapped_port" >&2
                        exit 1
                      fi
                    fi
                  '';

                  Group = "qbittorrent";
                  Type = "oneshot";
                  User = "qbittorrent";
                };
              };
            };

            # ProtonVPN reclaims the NAT-PMP mapping after 60s of inactivity; refresh well before
            # that.
            timers.qbittorrent-portforward = {
              description = "Periodically refresh qBittorrent's ProtonVPN NAT-PMP port mapping";

              timerConfig = {
                OnActiveSec = "10s";
                OnUnitActiveSec = "45s";
                Unit = "qbittorrent-portforward.service";
              };

              wantedBy = [ "timers.target" ];
            };
          };

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

          vpnNamespaces.${namespace} = {
            inherit namespaceAddress;
            enable = true;
            accessibleFrom = [ "10.10.10.0/24" ];

            portMappings = [
              {
                from = port;
                to = port;
              }
            ];

            wireguardConfigFile = config.age.secrets."wg-US-CA-888.conf".path;
          };
        };

      nixosSecrets."wg-US-CA-888.conf".rekeyFile = ../../../secrets/wg-US-CA-888.conf.age;

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
              printf 'CROSS_SEED_API_KEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps."cross-seed-api-key".file})"
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
        upstreamHost = namespaceAddress;
      };

      vpn-confinement = [
        "qbittorrent"
        "qbittorrent-portforward"
      ];
    };
}
