{ ... }:
{
  my.healthchecks.nixos =
    { config, pkgs, ... }:
    let
      hostName = config.networking.hostName;

      # Shared helper to post a message to Discord via webhook
      sendDiscordScript = pkgs.writeShellApplication {
        name = "send-discord-message";
        runtimeInputs = with pkgs; [ curl jq ];
        text = ''
          # shellcheck disable=SC1090
          source "${config.age.secrets."discord-webhook.env".path}"
          PAYLOAD=$(jq -rn --arg content "$1" '{"content": $content}')
          curl -fsS -X POST "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            --data-binary "$PAYLOAD"
        '';
      };

      # Script used by ZED to send ZFS event notifications to Discord.
      # ZED invocation: $ZED_EMAIL_PROG -s "$SUBJECT" $ZED_EMAIL_ADDR < $TMPFILE
      zedNotifyScript = pkgs.writeShellApplication {
        name = "zed-discord-notify";
        runtimeInputs = [ sendDiscordScript ];
        text = ''
          SUBJECT=""
          while getopts "s:r:" opt; do
            case "$opt" in
              s) SUBJECT="$OPTARG" ;;
              *) ;;
            esac
          done
          BODY=$(cat)

          send-discord-message "$(printf '🚨 **ZFS Alert on ${hostName}**\n**%s**\n```\n%s\n```' "$SUBJECT" "$BODY")"
        '';
      };

      # Periodic health check script for temperature and disk utilization
      healthCheckScript = pkgs.writeShellApplication {
        name = "harmony-healthcheck";
        runtimeInputs = with pkgs; [ coreutils gawk gnugrep lm_sensors zfs ] ++ [ sendDiscordScript ];
        text = ''
          ALERTS=""

          # Check ZFS pool health and capacity
          while IFS= read -r pool; do
            HEALTH=$(zpool list -H -o health "$pool" 2>/dev/null || echo "UNKNOWN")
            if [ "$HEALTH" != "ONLINE" ]; then
              STATUS=$(zpool status "$pool" 2>&1 || true)
              ALERTS="$ALERTS"$'\n'"⚠️ ZFS pool \`$pool\` is $HEALTH"$'\n'"$STATUS"
            fi
            CAP=$(zpool list -H -o cap "$pool" 2>/dev/null | tr -d '%' || true)
            if [ -n "$CAP" ] && [ "$CAP" -gt 85 ]; then
              ALERTS="$ALERTS"$'\n'"💾 ZFS pool \`$pool\` is ''${CAP}% full"
            fi
          done < <(zpool list -H -o name 2>/dev/null || true)

          # Check CPU temperature (warn above 80°C)
          MAX_TEMP=$(sensors 2>/dev/null \
            | grep -oP '(?<=\+)[0-9.]+(?=°C)' \
            | sort -rn | head -1 || true)
          MAX_TEMP=${MAX_TEMP:-0}
          if awk "BEGIN{exit !($MAX_TEMP > 80)}"; then
            ALERTS="$ALERTS"$'\n'"🌡️ High temperature: ''${MAX_TEMP}°C"
          fi

          # Check disk utilization for non-ZFS filesystems (warn above 85%)
          while IFS= read -r line; do
            USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
            MOUNT=$(echo "$line" | awk '{print $6}')
            [ -n "$USAGE" ] || continue
            if [ "$USAGE" -gt 85 ]; then
              ALERTS="$ALERTS"$'\n'"💾 Disk \`$MOUNT\` is ''${USAGE}% full"
            fi
          done < <(df -P -l -x zfs -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2 || true)

          if [ -n "$ALERTS" ]; then
            send-discord-message "$(printf '🚨 **${hostName} Health Alert**\n%s' "$ALERTS")"
          fi
        '';
      };
    in
    {
      # ZFS Event Daemon: send Discord notifications for ZFS pool events
      services.zfs.zed = {
        enableMail = false;
        settings = {
          ZED_EMAIL_PROG = "${zedNotifyScript}/bin/zed-discord-notify";
          ZED_EMAIL_ADDR = "discord";
          ZED_NOTIFY_VERBOSE = 0;
          ZED_NOTIFY_INTERVAL_SECS = 3600;
        };
      };

      # Periodic health check timer
      systemd = {
        services.harmony-healthcheck = {
          description = "Harmony health check with Discord notifications";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${healthCheckScript}/bin/harmony-healthcheck";
          };
        };

        timers.harmony-healthcheck = {
          description = "Harmony periodic health check";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "hourly";
            Persistent = true;
          };
        };
      };
    };
}
