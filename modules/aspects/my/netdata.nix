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

            "netdata-api.htpasswd" = {
              generator = {
                dependencies = { inherit (secrets) netdata-api-key; };

                # APR1-MD5 (`openssl passwd -apr1`), not bcrypt: nginx's auth_basic only verifies
                # crypt/APR1-MD5/SHA hashes, not bcrypt, so `htpasswd -B` would produce a hash
                # nginx can never match.
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

              group = "nginx";
              # Read directly by nginx's worker process (auth_basic_user_file), not by a systemd
              # service with its own user= - defaults to root:root mode 0400 otherwise, which
              # nginx can't open (500s every request to the netdata-api vhost with a bare "open()
              # ... Permission denied" in its error log).
              owner = "nginx";
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

          configDir = {
            # Stock file plus one added skip rule matching both port 9001 (authentik's embedded
            # outpost) and port 9301 (authentik's Django metrics endpoint): go.d's generic
            # "exporter" catch-all rule misidentifies both, guessing exporter identity from
            # well-known third-party ports (9001 -> supervisord/jitsi-videobridge, 9301 ->
            # squid-exporter) with no way to know it's actually authentik - one of those guesses
            # returns an empty body (permanent "check failed: expected a valid start token, got
            # \"<\"" collector-status alerts), the other happens to return authentik's real
            # prometheus output but mislabeled as squid. There's no smaller/per-job override for
            # this - see https://github.com/netdata/netdata/discussions/20921. Everything else in
            # the file is an unmodified copy of upstream's matchers - a netdata package bump won't
            # bring in any new upstream matchers added since, so re-diff against the new version's
            # stock file if a legitimate third-party exporter stops auto-detecting after a bump.
            "go.d/sd/net_listeners.conf" = ./netdata-net-listeners.conf;

            # Stock health.d/systemdunits.conf ships every "unit in the failed state" template with
            # `chart labels: unit_name=!*` - Netdata's simple-pattern matching treats a bare `!*` as
            # "reject every value, nothing left to accept", so by design none of these ever match any
            # chart until a local override lists which units to actually watch. Confirmed live: the
            # `systemd.service_unit_state` chart correctly showed harmony-tf-apply.service as
            # "failed", but `/api/v1/alarms` had zero `*_unit_failed_state` instances - the collector
            # works, this template just silently never attaches to anything out of the box.
            # `unit_name=*` (matching any unit) instead, for every unit type - otherwise identical to
            # upstream's own health.d/systemdunits.conf.
            "health.d/systemdunits.conf" = pkgs.writeText "systemdunits.conf" ''
              # you can disable an alarm notification by setting the 'to' line to: silent

              ## Service units
                  template: systemd_service_unit_failed_state
                        on: systemd.service_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd service unit in the failed state
                        to: sysadmin

              ## Socket units
                  template: systemd_socket_unit_failed_state
                        on: systemd.socket_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd socket unit in the failed state
                        to: sysadmin

              ## Target units
                  template: systemd_target_unit_failed_state
                        on: systemd.target_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd target unit in the failed state
                        to: sysadmin

              ## Path units
                  template: systemd_path_unit_failed_state
                        on: systemd.path_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd path unit in the failed state
                        to: sysadmin

              ## Device units
                  template: systemd_device_unit_failed_state
                        on: systemd.device_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd device unit in the failed state
                        to: sysadmin

              ## Mount units
                  template: systemd_mount_unit_failed_state
                        on: systemd.mount_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd mount units in the failed state
                        to: sysadmin

              ## Automount units
                  template: systemd_automount_unit_failed_state
                        on: systemd.automount_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd automount unit in the failed state
                        to: sysadmin

              ## Swap units
                  template: systemd_swap_unit_failed_state
                        on: systemd.swap_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd swap units in the failed state
                        to: sysadmin

              ## Scope units
                  template: systemd_scope_unit_failed_state
                        on: systemd.scope_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd scope units in the failed state
                        to: sysadmin

              ## Slice units
                  template: systemd_slice_unit_failed_state
                        on: systemd.slice_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd slice units in the failed state
                        to: sysadmin

              ## Timer units
                  template: systemd_timer_unit_failed_state
                        on: systemd.timer_unit_state
                     class: Errors
                      type: Linux
                 component: Systemd units
              chart labels: unit_name=*
                      calc: $failed
                     units: state
                     every: 10s
                      warn: $this != nan AND $this == 1
                     delay: down 5m multiplier 1.5 max 1h
                   summary: systemd unit ${"$"}{label:unit_name} state
                      info: systemd timer unit in the failed state
                        to: sysadmin
            '';

            # Discord notifications via health_alarm_notify.conf.
            # The file is a bash script sourced by Netdata's alarm-notify.sh;
            # sourcing the age secret sets DISCORD_WEBHOOK_URL at runtime.
            "health_alarm_notify.conf" = pkgs.writeText "health_alarm_notify.conf" ''
              # shellcheck disable=SC1090
              source "${config.age.secrets."netdata-secrets.env".path}"
              SEND_DISCORD="YES"
              DEFAULT_RECIPIENT_DISCORD="alarms"

              # No local MTA on this host; Netdata Cloud already sends email
              # notifications, so don't bother with alarm-notify.sh's own
              # (broken, sendmail-dependent) email path.
              SEND_EMAIL="NO"
            '';
          };

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

        "netdata-secrets.env" = {
          generator = {
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

          # netdata.service runs as the `netdata` user, and alarm-notify.sh sources this file
          # directly (not via systemd LoadCredential), so it needs to be readable by that user
          # rather than the agenix default of root-only - same class of bug as
          # netdata-api.htpasswd needing owner = "nginx" above, just for the service itself this
          # time instead of nginx. Root-caused on the deployed harmony after most
          # apcupsd_last_collected_secs alarm transitions showed exec_code: 1/EXEC_FAILED on their
          # Discord notification - alarm-notify.sh couldn't read DISCORD_WEBHOOK_URL from a
          # root-only file while running as `netdata`.
          owner = "netdata";
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
