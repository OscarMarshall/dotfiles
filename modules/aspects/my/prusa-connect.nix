# Prusa Connect (https://www.prusa3d.com/p/connect/connect-local/get-started/) - Prusa's self-hosted,
# local-first printer server (github.com/prusa3d/prusa-connect), still in beta. Not in nixpkgs, so
# this fetches the upstream release binary (static Go, web app embedded - runs as-is on NixOS).
#
# Two sockets, both from the same process:
#   - `port` (loopback only) - the web app, REST API and event stream, reverse-proxied by nginx and
#     logged into through Authentik over OIDC (`virtual-host.oidc` below). Not `protected`: the
#     app holds its own sessions, and its own OIDC login also covers anyone on the LAN.
#   - `printerPort` (every interface, opened in the firewall) - the xBuddy connector's own
#     listener, which serves ONLY the routes a printer dials (everything else 404s). Printers can't
#     go through nginx: the hostname they dial is stored in 20 bytes, which no
#     `*.harmony.<domain>` name fits in, so they dial harmony's LAN IP directly instead.
#     `printer_address` writes that into the prusa_printer_settings.ini the add-printer page offers.
#
# One-time first run after deploying: the server prints a setup code in its log
# (`journalctl -u prusa-connect | grep -i code`); open the vhost, enter it, and answer the wizard's
# remaining questions (printer admission, storage). Sign-in is already fixed by this config, so the
# wizard skips it - `administrator` below is the Authentik username that gets admin.
let
  port = 8088;
  printerPort = 8089;
  dataDir = "/metalminds/prusa-connect";
  version = "0.1.0-beta.1";
in
{
  my.prusa-connect =
    { administrator }:
    { host, ... }:
    let
      name = "prusa-connect";
      url = "${name}.${host.name}.${host.domain}";
    in
    {
      dataset = {
        inherit name;
        backup = true;
        group = "prusa-connect";
        pool = "metalminds";
        units = [ "prusa-connect" ];
        user = "prusa-connect";
      };

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          package = pkgs.stdenvNoCC.mkDerivation {
            inherit version;
            pname = "prusa-connect";

            src = pkgs.fetchurl {
              url = "https://github.com/prusa3d/prusa-connect/releases/download/v${version}/prusa_connect_amd64";
              hash = "sha256-o6H2lhG8WexdrUlKvQ/QTbeVL9esb1Gc4JeCF+jPY6U=";
            };

            dontUnpack = true;
            installPhase = "install -Dm755 $src $out/bin/prusa-connect";
            meta.platforms = [ "x86_64-linux" ];
          };

          # JSON is YAML, and every key here is one config/config.yaml in the release documents.
          # The client secret is merged in at start (preStart below) so it never lands in the store.
          settings = (pkgs.formats.json { }).generate "prusa-connect-config.json" {
            core = {
              api.addr = "127.0.0.1:${toString port}";

              auth = {
                client_id = name; # authentik.nix sets every oidc provider's client_id to `vh.name`
                issuer = "https://${config.services.authentik.nginx.host}/application/o/${name}/";
                redirect_uri = "https://${url}/api/v1/auth/callback";
              };

              connectors.xbuddy = {
                config.listener.addr = ":${toString printerPort}"; # no `tls` = plain HTTP
                enabled = true;
                type = "xbuddy";
              };

              # mDNS would advertise the loopback-only API port, which nothing else can reach.
              discovery.enabled = false;
              frontend.printer_address = "http://${host.lan-ip}:${toString printerPort}";
              # The `sub` (oidc.sub-mode = "user_username" below) granted admin on first start.
              principal = administrator;
              trusted_proxies = [ "127.0.0.1" ];
              # Nix owns the binary; the self-updater would try to replace it.
              upgrade.enabled = false;
            };

            resources.storage.local = {
              config.root = "./storage";
              enabled = true;
              required = true;
              type = "filesystem";
            };
          };
        in
        {
          networking.firewall.allowedTCPPorts = [ printerPort ];

          systemd.services.prusa-connect = {
            description = "Prusa Connect, a local server for 3D printers";
            # The server reads Authentik's discovery document before serving anything, and exits if
            # it can't - so wait for it, and keep retrying (no start limit) if Authentik is slow.
            after = [
              "authentik.service"
              "network-online.target"
              "nginx.service"
            ];

            startLimitIntervalSec = 0;
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];

            # config.yaml lives in the data dir rather than the store: the setup wizard writes its
            # answers (and installed extensions) into `config.d/` beside it.
            preStart = ''
              ${lib.getExe pkgs.jq} --rawfile secret "$CREDENTIALS_DIRECTORY/client-secret" \
                '.core.auth.client_secret = ($secret | rtrimstr("\n"))' ${settings} > config.yaml
            '';

            # Hardening mirrors upstream's deploy/systemd/prusa-connect.service.
            serviceConfig = {
              AmbientCapabilities = "CAP_NET_BIND_SERVICE";
              CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
              ExecStart = "${lib.getExe' package "prusa-connect"} -config ${dataDir}/config.yaml";
              Group = "prusa-connect";
              LoadCredential = "client-secret:${config.age.secrets.prusa-connect-oidc-client-secret.path}";
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              NoNewPrivileges = true;
              PrivateDevices = true;
              PrivateTmp = true;
              ProcSubset = "pid";
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              ProtectSystem = "strict";
              ReadWritePaths = [ dataDir ];
              RemoveIPC = true;

              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_NETLINK"
                "AF_UNIX"
              ];

              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              Restart = "on-failure";
              RestartSec = "10s";
              SystemCallArchitectures = "native";

              SystemCallFilter = [
                "@system-service"
                "~@privileged @resources"
              ];

              TimeoutStopSec = "30s";
              UMask = "0077";
              User = "prusa-connect";
              WorkingDirectory = dataDir;
            };
          };

          users = {
            groups.prusa-connect = { };

            users.prusa-connect = {
              group = "prusa-connect";
              isSystemUser = true;
            };
          };
        };

      secrets.prusa-connect-oidc-client-secret = {
        generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
        settings.terraform = "variable";
      };

      virtual-host = {
        inherit name port;
        group = "Infra";
        homepage.description = "3D printer fleet";
        host = host.name;
        icon = "mdi-printer-3d";
        label = "Prusa Connect";
        # Print files (.bgcode/.3mf) easily run to hundreds of MB.
        maxBodySize = "2G";

        oidc = {
          client-secret = "prusa-connect-oidc-client-secret";
          redirect-paths = [ "/api/v1/auth/callback" ];
          # Authentik's default `sub` is a hashed id nobody can know before the first login;
          # usernames give `principal` above something to name.
          sub-mode = "user_username";
        };

        websockets = true;
      };
    };
}
