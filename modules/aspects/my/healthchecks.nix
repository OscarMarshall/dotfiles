let
  url = "netdata.harmony.silverlight-nex.us";
  port = 19999;
in
{
  my.healthchecks = {
    virtual-host = {
      name = "netdata";
      protected = true;
      inherit url port;
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
        # Bind only to loopback; nginx handles external access
        config.web."bind to" = "127.0.0.1";
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
