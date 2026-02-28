{ my, ... }:
{
  my.healthchecks =
    let
      port = 19999;
    in
    {
      includes = [ (my.nginx._.virtual-host "netdata.harmony.silverlight-nex.us" port) ];

      nixos =
        { config, pkgs, ... }:
        let
          hostName = config.networking.hostName;

          # Script used by ZED to send ZFS event notifications to Discord.
          # ZED invocation: $ZED_EMAIL_PROG -s "$SUBJECT" $ZED_EMAIL_ADDR < $TMPFILE
          zedNotifyScript = pkgs.writeShellApplication {
            name = "zed-discord-notify";
            runtimeInputs = with pkgs; [ curl jq ];
            text = ''
              # shellcheck disable=SC1090
              source "${config.age.secrets."discord-webhook.env".path}"
              SUBJECT=""
              while getopts "s:r:" opt; do
                case "$opt" in
                  s) SUBJECT="$OPTARG" ;;
                  *) ;;
                esac
              done
              BODY=$(cat)
              MESSAGE=$(printf '🚨 **ZFS Alert on ${hostName}**\n**%s**\n```\n%s\n```' \
                "$SUBJECT" "$BODY")
              PAYLOAD=$(jq -rn --arg content "$MESSAGE" '{"content": $content}')
              curl -fsS -X POST "$DISCORD_WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                --data-binary "$PAYLOAD"
            '';
          };
        in
        {
          # ZFS Event Daemon: send Discord notifications for real-time ZFS pool events
          services.zfs.zed = {
            enableMail = false;
            settings = {
              ZED_EMAIL_PROG = "${zedNotifyScript}/bin/zed-discord-notify";
              ZED_EMAIL_ADDR = "discord";
              ZED_NOTIFY_VERBOSE = 0;
              ZED_NOTIFY_INTERVAL_SECS = 3600;
            };
          };

          # Netdata monitoring (metrics, dashboards, and Discord health alerts)
          services.netdata = {
            enable = true;
            # Bind only to loopback; nginx handles external access
            config.web."bind to" = "127.0.0.1";
            # Discord notifications via health_alarm_notify.conf.
            # The file is a bash script sourced by Netdata's alarm-notify.sh;
            # sourcing the age secret sets DISCORD_WEBHOOK_URL at runtime.
            configDir."health_alarm_notify.conf" = pkgs.writeText "health_alarm_notify.conf" ''
              # shellcheck disable=SC1090
              source "${config.age.secrets."discord-webhook.env".path}"
              SEND_DISCORD="YES"
              DEFAULT_RECIPIENT_DISCORD="alarms"
            '';
          };
        };
    };
}
