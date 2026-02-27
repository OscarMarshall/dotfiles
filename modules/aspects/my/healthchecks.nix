{ my, ... }:
{
  my.healthchecks =
    let
      port = 8090;
    in
    {
      includes = [ (my.nginx._.virtual-host "beszel.harmony.silverlight-nex.us" port) ];

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

          # Beszel monitoring hub (web dashboard)
          services.beszel.hub = {
            enable = true;
            host = "127.0.0.1";
            inherit port;
          };

          # Beszel monitoring agent (same machine)
          services.beszel.agent = {
            enable = true;
            environmentFile = config.age.secrets."beszel-agent.env".path;
            smartmon.enable = true;
          };
        };
    };
}
