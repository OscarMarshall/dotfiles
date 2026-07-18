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
      includes = [ (den._.unfree [ "netdata" ]) ];

      virtual-host = {
        name = "netdata";
        host = host.name;
        protected = true;
        inherit port global;
        label = "Netdata";
        icon = "netdata.svg";
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
      };

      secrets = { secrets, ... }: {
        discord-webhook-url = {
          rekeyFile = ../../../secrets/discord-webhook-url.age;
          intermediary = true;
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

      nixos = { config, pkgs, ... }: {
        # Netdata monitoring (metrics, dashboards, and Discord health alerts)
        # Includes built-in ZFS pool health/capacity alerting.
        services.netdata = {
          enable = true;
          # withCloudUi pulls in the local dashboard's static files; without it the package omits
          # them entirely and every request 404s with "File does not exist, or is not accessible:".
          package = pkgs.netdata.override { withCloudUi = true; };
          # Bind only to loopback; nginx handles external access
          config.web."bind to" = "127.0.0.1";
          # smartmontools gives the smartctl collector S.M.A.R.T. access to individual disks
          # (pre-fail indicators), complementing the built-in ZFS pool-level health alerting above.
          extraNdsudoPackages = [ pkgs.smartmontools ];
          # Discord notifications via health_alarm_notify.conf.
          # The file is a bash script sourced by Netdata's alarm-notify.sh;
          # sourcing the age secret sets DISCORD_WEBHOOK_URL at runtime.
          configDir."health_alarm_notify.conf" = pkgs.writeText "health_alarm_notify.conf" ''
            # shellcheck disable=SC1090
            source "${config.age.secrets."netdata-secrets.env".path}"
            SEND_DISCORD="YES"
            DEFAULT_RECIPIENT_DISCORD="alarms"
          '';
        };
      };
    };
}
