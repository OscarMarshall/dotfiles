let
  # Not a real mailbox - PocketBase (what Beszel's hub is built on) only validates the shape of
  # `USER_EMAIL`, never delivers to it. A fixed literal (not derived from `host.domain`) so
  # claude.nix can reference the exact same string independently without needing this file's own
  # `let` bindings - see that file's own comment on this value.
  adminEmail = "admin@beszel.local";
  agentPort = 45876;
  hubPort = 8090;
in
{
  my.beszel =
    {
      global ? false,
    }:
    { host, ... }: {
      # The second entry contributes a SEPARATE vhost (beszel-api.<host>.<domain>) dedicated to
      # programmatic access to Beszel's REST API, mirroring the same split netdata.nix used to
      # use. Beszel's hub already requires its own login (unlike Netdata, which had none), but
      # Authentik's forward-auth is still built around browser session cookies, not something a
      # non-interactive `curl` from Claude Code can complete - so this second vhost proxies to the
      # same backend but gates on HTTP Basic Auth instead, purely to get a script past Authentik.
      # The actual Beszel API call still needs a real login on top (see claude.nix).
      includes = [
        {
          secrets = { secrets, ... }: {
            # The raw token - never read by nginx directly, only used to derive the htpasswd file
            # below. Kept as its own secret (rather than inlined into that generator) so its
            # plaintext stays retrievable for actually using the API, matching
            # `beszel-admin-password` below and Sonarr/Radarr/Prowlarr's own api-key secrets.
            beszel-api-key = {
              generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
              intermediary = true;
            };

            "beszel-api.htpasswd" = {
              generator = {
                dependencies = { inherit (secrets) beszel-api-key; };

                # APR1-MD5 (`openssl passwd -apr1`), not bcrypt: nginx's auth_basic only verifies
                # crypt/APR1-MD5/SHA hashes, not bcrypt - see netdata.nix's own history of this
                # exact gotcha (git blame) for the confirmed failure mode.
                script =
                  {
                    lib,
                    pkgs,
                    decrypt,
                    deps,
                    ...
                  }:
                  ''
                    printf 'beszel:%s\n' "$(
                      ${pkgs.openssl}/bin/openssl passwd -apr1 "$(${decrypt} ${lib.escapeShellArg deps.beszel-api-key.file})"
                    )"
                  '';
              };

              group = "nginx";
              # Read directly by nginx's worker process (auth_basic_user_file), not by a systemd
              # service with its own user= - defaults to root:root mode 0400 otherwise, which
              # nginx can't open. Same bug class netdata.nix's identical secret hit first.
              owner = "nginx";
            };
          };

          virtual-host = {
            inherit host;
            basicAuthSecret = "beszel-api.htpasswd";
            name = "beszel-api";
            port = hubPort;
          };
        }
      ];

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          services.beszel = {
            agent = {
              enable = true;

              environment = {
                HUB_URL = "http://127.0.0.1:${toString hubPort}";
                # Written by beszel-bootstrap.service below, once the hub has actually minted
                # them - see that service's own comment for why this can't be done ahead of time
                # via Nix/agenix the way every other secret in this repo is.
                KEY_FILE = "/var/lib/beszel-agent/id_ed25519.pub";
                # Netdata's stock `unit_name=!*` matcher (see the old netdata.nix, now removed)
                # matched nothing by design until overridden - Beszel's own default is unset
                # (undocumented whether that means "everything" or "nothing"), so this pins it to
                # the same "watch every unit" intent explicitly rather than relying on a guess.
                SERVICE_PATTERNS = "*";
                SYSTEM_NAME = host.name;
                TOKEN_FILE = "/var/lib/beszel-agent/token";
              };

              smartmon.enable = true;
            };

            hub = {
              enable = true;

              environment = {
                # Used for links in Beszel's own emails/notifications, not for routing - nginx
                # still fronts the real traffic.
                APP_URL = "https://beszel.${host.name}.${host.domain}";
                USER_EMAIL = adminEmail;
              };

              environmentFile = config.age.secrets."beszel-hub.env".path;
            };
          };

          # Beszel has no declarative bootstrap for hub<->agent pairing the way NixOS module
          # options usually give us one: the hub mints its own SSH keypair and per-agent tokens
          # entirely at runtime (there's nothing to pre-seed via agenix), and the only documented
          # way to fetch them is this same REST API a human would otherwise click through in the
          # web UI (Settings > Tokens, then Systems > Add System) - confirmed against
          # nixpkgs' own `beszel.nix` NixOS test, which drives this exact sequence. This service
          # replays that sequence automatically on every boot: authenticate as the `USER_EMAIL`/
          # `USER_PASSWORD` admin account beszel-hub.env bootstraps, fetch the hub's SSH public
          # key and a universal registration token, write them where the agent's `KEY_FILE`/
          # `TOKEN_FILE` above expect them, and register this host as a system if it isn't
          # already one (checked by name first - the endpoint has no upsert, so a second POST
          # would otherwise create a duplicate `harmony` system every rebuild).
          #
          # Runs as the same static `beszel-agent` user the agent itself runs as (created by
          # nixpkgs' own module whenever `SERVICE_PATTERNS`/systemd monitoring isn't disabled),
          # so it can write into the agent's own `StateDirectory` without a separate user/ACL to
          # manage.
          systemd.services = {
            # Racing beszel-bootstrap: `wantedBy = multi-user.target` on the agent's own upstream
            # module unit starts it in parallel with everything else on this same target,
            # including bootstrap above - without this, the agent can start (and fail to read
            # KEY_FILE/TOKEN_FILE, or read stale ones from a previous boot) before bootstrap has
            # written this boot's copies.
            beszel-agent = {
              after = [ "beszel-bootstrap.service" ];
              requires = [ "beszel-bootstrap.service" ];
            };

            beszel-bootstrap = {
              description = "Register ${host.name}'s Beszel agent with its local hub";
              wantedBy = [ "multi-user.target" ];
              after = [ "beszel-hub.service" ];
              requires = [ "beszel-hub.service" ];

              serviceConfig = {
                EnvironmentFile = config.age.secrets."beszel-hub.env".path;

                ExecStart = pkgs.writeShellScript "beszel-bootstrap" ''
                  set -euo pipefail
                  hub_url="http://127.0.0.1:${toString hubPort}"

                  attempt=1
                  max_attempts=60
                  until ${pkgs.curl}/bin/curl -fs "$hub_url/api/health" >/dev/null; do
                    if [ "$attempt" -ge "$max_attempts" ]; then
                      echo "beszel-hub never became healthy after $max_attempts attempts" >&2
                      exit 1
                    fi
                    attempt=$((attempt + 1))
                    sleep 1
                  done

                  auth_response="$(
                    ${pkgs.curl}/bin/curl -fsS -X POST "$hub_url/api/collections/users/auth-with-password" \
                      -H 'Content-Type: application/json' \
                      -d "$(${pkgs.jq}/bin/jq -cn --arg identity ${lib.escapeShellArg adminEmail} --arg password "$USER_PASSWORD" '{identity:$identity,password:$password}')"
                  )"
                  token="$(${pkgs.jq}/bin/jq -r '.token' <<<"$auth_response")"
                  user_id="$(${pkgs.jq}/bin/jq -r '.record.id' <<<"$auth_response")"

                  sshkey="$(${pkgs.curl}/bin/curl -fsS -H "Authorization: $token" "$hub_url/api/beszel/getkey" | ${pkgs.jq}/bin/jq -r '.key')"
                  utoken="$(${pkgs.curl}/bin/curl -fsS -H "Authorization: $token" "$hub_url/api/beszel/universal-token" | ${pkgs.jq}/bin/jq -r '.token')"

                  printf '%s' "$sshkey" > "$STATE_DIRECTORY/id_ed25519.pub"
                  chmod 444 "$STATE_DIRECTORY/id_ed25519.pub"
                  printf '%s' "$utoken" > "$STATE_DIRECTORY/token"
                  chmod 400 "$STATE_DIRECTORY/token"

                  existing="$(
                    ${pkgs.curl}/bin/curl -fsS -G -H "Authorization: $token" \
                      --data-urlencode "filter=(name='${host.name}')" \
                      "$hub_url/api/collections/systems/records" | ${pkgs.jq}/bin/jq -r '.items | length'
                  )"
                  if [ "$existing" -eq 0 ]; then
                    ${pkgs.curl}/bin/curl -fsS -X POST "$hub_url/api/collections/systems/records" \
                      -H "Authorization: $token" -H 'Content-Type: application/json' \
                      -d "$(
                        ${pkgs.jq}/bin/jq -cn \
                          --arg host 127.0.0.1 \
                          --arg name ${lib.escapeShellArg host.name} \
                          --arg pkey "$sshkey" \
                          --arg tkn "$utoken" \
                          --arg users "$user_id" \
                          '{host:$host,name:$name,pkey:$pkey,port:"${toString agentPort}",tkn:$tkn,users:$users}'
                      )"
                  fi
                '';

                Group = "beszel-agent";
                RemainAfterExit = true;
                StateDirectory = "beszel-agent";
                Type = "oneshot";
                User = "beszel-agent";
              };
            };
          };
        };

      secrets = { secrets, ... }: {
        beszel-admin-password = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
        };

        # Beszel's alert notifications are configured entirely through its web UI (Settings >
        # Notifications) using Shoutrrr URL schemas - there's no environment variable or config
        # file Beszel reads them from, unlike Netdata's file-based `health_alarm_notify.conf`
        # (see git history on the old netdata.nix). This can't be closed the same way
        # beszel-bootstrap.service closes the agent-pairing gap above: notification URLs live in
        # a per-user settings record with no documented REST shape to target confidently. This
        # secret exists purely so the one remaining manual step - pasting this value into
        # Settings > Notifications, once - doesn't also require hand-converting Discord's webhook
        # URL into Shoutrrr's `discord://token@id` format:
        # `agenix decrypt secrets/generated/beszel-discord-webhook.age`.
        beszel-discord-webhook.generator = {
          dependencies = { inherit (secrets) discord-webhook-url; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              webhook_url="$(${decrypt} ${lib.escapeShellArg deps.discord-webhook-url.file})"
              id="$(printf '%s' "$webhook_url" | sed -E 's#.*/webhooks/([0-9]+)/([^/?]+).*#\1#')"
              token="$(printf '%s' "$webhook_url" | sed -E 's#.*/webhooks/([0-9]+)/([^/?]+).*#\2#')"
              printf 'discord://%s@%s\n' "$token" "$id"
            '';
        };

        "beszel-hub.env".generator = {
          dependencies = { inherit (secrets) beszel-admin-password; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'USER_PASSWORD=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.beszel-admin-password.file})"
            '';
        };

        # Reused from the old netdata.nix - same Discord app, so the primitive secret itself
        # (obtained from Discord's own UI) doesn't need to change, only what derives from it.
        discord-webhook-url = {
          intermediary = true;
          rekeyFile = ../../../secrets/discord-webhook-url.age;
        };
      };

      virtual-host = {
        inherit global;
        group = "Infra";

        homepage = {
          description = "System monitoring & alerts";
          # No `widget`, unlike netdata.nix's: Homepage's Beszel widget needs a `systemId` that
          # Beszel only assigns once the hub has actually registered a system (see
          # beszel-bootstrap.service above) - a runtime value with nowhere to live in this static
          # config. Add one by hand later (Settings > Widgets in Homepage's docs) once that id is
          # known, if live stats on the tile are worth it over just linking through.
        };

        host = host.name;
        icon = "beszel.svg";
        label = "Beszel";
        name = "beszel";
        port = hubPort;
        protected = true;
      };
    };
}
