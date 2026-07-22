let
  port = 19999;
in
{ den, ... }: {
  my.netdata =
    {
      global ? false,
    }:
    { host, ... }: {
      # withCloudUi's dashboard files (below) are under the non-free Netdata Cloud UI License.
      #
      # The second entry contributes a SEPARATE vhost (netdata-api.<host>.<domain>) dedicated to
      # programmatic access to Netdata's REST API. It deliberately doesn't touch the main
      # `virtual-host` below: that one stays Authentik-protected end to end, since the dashboard
      # SPA calls the exact same /api/v1 and /api/v2 endpoints to render itself, so gating them
      # differently there would break chart/alarm loading for anyone logged into the dashboard.
      # This second vhost proxies to the same backend but gates on HTTP Basic Auth instead -
      # Authentik's forward-auth is built around browser session cookies, not a static API key, so
      # it isn't a good fit for machine-to-machine calls.
      includes = [
        (den._.unfree [ "netdata" ])
        {
          secrets = { secrets, ... }: {
            # The raw token - never read by nginx directly, only used to derive the htpasswd file
            # below. Kept as its own secret (rather than inlined into that generator) so its
            # plaintext stays retrievable (`agenix decrypt secrets/generated/netdata-api-key.age`)
            # for actually using the API, matching Sonarr/Radarr/Prowlarr's own api-key secrets.
            netdata-api-key = {
              generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
              intermediary = true;
            };

            "netdata-api.htpasswd".generator = {
              dependencies = { inherit (secrets) netdata-api-key; };

              # APR1-MD5 (`openssl passwd -apr1`), not bcrypt: nginx's auth_basic only verifies
              # crypt/APR1-MD5/SHA hashes, not bcrypt, so `htpasswd -B` would produce a hash nginx
              # can never match.
              script =
                {
                  lib,
                  pkgs,
                  decrypt,
                  deps,
                  ...
                }:
                ''
                  printf 'netdata:%s\n' "$(
                    ${pkgs.openssl}/bin/openssl passwd -apr1 "$(${decrypt} ${lib.escapeShellArg deps.netdata-api-key.file})"
                  )"
                '';
            };
          };

          virtual-host = {
            inherit port;
            basicAuthSecret = "netdata-api.htpasswd";
            host = host.name;
            name = "netdata-api";
          };
        }
      ];

      nixos = { config, pkgs, ... }: {
        # Netdata monitoring (metrics, dashboards, and Discord health alerts)
        # Includes built-in ZFS pool health/capacity alerting.
        services.netdata = {
          # Bind only to loopback; nginx handles external access
          config.web."bind to" = "127.0.0.1";
          enable = true;
          # withCloudUi pulls in the local dashboard's static files; without it the package omits
          # them entirely and every request 404s with "File does not exist, or is not accessible:".
          package = pkgs.netdata.override { withCloudUi = true; };

          # Discord notifications via health_alarm_notify.conf.
          # The file is a bash script sourced by Netdata's alarm-notify.sh;
          # sourcing the age secret sets DISCORD_WEBHOOK_URL at runtime.
          configDir."health_alarm_notify.conf" = pkgs.writeText "health_alarm_notify.conf" ''
            # shellcheck disable=SC1090
            source "${config.age.secrets."netdata-secrets.env".path}"
            SEND_DISCORD="YES"
            DEFAULT_RECIPIENT_DISCORD="alarms"
          '';

          # smartmontools gives the smartctl collector S.M.A.R.T. access to individual disks
          # (pre-fail indicators), complementing the built-in ZFS pool-level health alerting above.
          extraNdsudoPackages = [ pkgs.smartmontools ];
        };
      };

      secrets = { secrets, ... }: {
        discord-webhook-url = {
          intermediary = true;
          rekeyFile = ../../../secrets/discord-webhook-url.age;
        };

        "netdata-secrets.env".generator = {
          dependencies = { inherit (secrets) discord-webhook-url; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'DISCORD_WEBHOOK_URL="%s"\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.discord-webhook-url.file}
              )"
            '';
        };
      };

      virtual-host = {
        inherit global port;
        group = "Infra";

        homepage = {
          description = "System monitoring & alerts";

          widget = {
            type = "netdata";
            # Hit Netdata directly rather than through nginx, since the public URL sits behind
            # Authentik forward-auth and would just redirect Homepage's server-side fetch to a
            # login page.
            url = "http://127.0.0.1:${toString port}";
          };
        };

        host = host.name;
        icon = "netdata.svg";
        label = "Netdata";
        name = "netdata";
        protected = true;
      };
    };
}
