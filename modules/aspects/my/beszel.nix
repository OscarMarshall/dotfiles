let
  # Not a real mailbox - PocketBase (what Beszel's hub is built on) only validates the shape of
  # `USER_EMAIL`, never delivers to it. A fixed literal (not derived from `host.domain`) so
  # claude.nix can reference the exact same string independently without needing this file's own
  # `let` bindings - see that file's own comment on this value.
  adminEmail = "admin@beszel.local";
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
            # plaintext stays retrievable for actually using the API, matching `beszel-password`
            # below and Sonarr/Radarr/Prowlarr's own api-key secrets.
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
            basicAuthSecret = "beszel-api.htpasswd";
            host = host.name;
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
                # Written by beszel-fetch-hub-key.service below, once the hub has actually
                # minted one - see that service's own comment for why this one piece still
                # can't be done through the Terraform provider (my.terranix below) the way
                # TOKEN_FILE now is.
                KEY_FILE = "/var/lib/beszel-agent/id_ed25519.pub";
                # Netdata's stock `unit_name=!*` matcher (see the old netdata.nix, now removed)
                # matched nothing by design until overridden - Beszel's own default is unset
                # (undocumented whether that means "everything" or "nothing"), so this pins it to
                # the same "watch every unit" intent explicitly rather than relying on a guess.
                SERVICE_PATTERNS = "*";
                SYSTEM_NAME = host.name;
              };

              # Points straight at the agenix secret Terraform is ALSO handed (as
              # `beszel_universal_token.${host.name}.token` below) - both sides agree on the
              # token's value without either one having to read the other's output, which this
              # repo has no mechanism for in the Terraform -> NixOS direction (every other
              # `settings.terraform` secret only ever flows the other way).
              environmentFile = config.age.secrets.beszel-agent-token.path;
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

          # Only the hub's own SSH public key still needs a raw REST call: it's minted at
          # runtime (nothing to pre-seed via agenix) and, unlike system/token/alert management
          # below, `leo-lem/terraform-provider-beszel` doesn't model the `/api/beszel/getkey`
          # route at all (it only covers Beszel's PocketBase collections, and this is a custom
          # route outside them - see that provider's own README). Authenticates as the same
          # `USER_EMAIL`/`USER_PASSWORD` admin account beszel-hub.env bootstraps.
          #
          # Runs as the same static `beszel-agent` user the agent itself runs as (created by
          # nixpkgs' own module whenever `SERVICE_PATTERNS`/systemd monitoring isn't disabled),
          # so it can write into the agent's own `StateDirectory` without a separate user/ACL to
          # manage.
          systemd.services = {
            # Merges into terranix.nix's own generic "${host.name}-tf-apply" unit (its `after`
            # only routes through nginx/authentik, the two "fixed choke points everything else
            # already routes through" per its own comment - beszel talks to its hub directly on
            # 127.0.0.1, bypassing both, so it needs its own entry here instead). Without this,
            # an apply that races a cold boot can run before beszel-hub has bootstrapped the
            # `USER_EMAIL` admin account, and `data.beszel_user.admin` below (a REQUIRED lookup)
            # fails outright rather than treating "no such user yet" as absent - caught by the
            # apply's own plan-retry loop either way, but this closes the race instead of
            # depending on that loop's ~40s budget being enough.
            "${host.name}-tf-apply" = {
              after = [ "beszel-hub.service" ];
              requires = [ "beszel-hub.service" ];
            };

            beszel-agent = {
              # Racing beszel-fetch-hub-key: `wantedBy = multi-user.target` on the agent's own
              # upstream module unit starts it in parallel with everything else on this same
              # target - without this, the agent can start (and fail to read KEY_FILE, or read a
              # stale one from a previous boot) before this has written this boot's copy.
              #
              # Deliberately NOT also ordered after "${host.name}-tf-apply.service" (which is
              # what actually creates the `beszel_system`/`beszel_universal_token` records the
              # agent's TOKEN_FILE above depends on) - the upstream module's own
              # `Restart = "on-failure"; RestartSec = "30s";` already retries a rejected token
              # every 30s, the same way terranix.nix's own apply retries a transient failure
              # rather than needing perfect ordering (see its own comment on why ordering alone
              # was never enough there either).
              after = [ "beszel-fetch-hub-key.service" ];
              requires = [ "beszel-fetch-hub-key.service" ];
            };

            beszel-fetch-hub-key = {
              description = "Fetch ${host.name}'s Beszel hub SSH public key for the local agent";
              wantedBy = [ "multi-user.target" ];
              after = [ "beszel-hub.service" ];
              requires = [ "beszel-hub.service" ];

              serviceConfig = {
                EnvironmentFile = config.age.secrets."beszel-hub.env".path;

                ExecStart = pkgs.writeShellScript "beszel-fetch-hub-key" ''
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

                  token="$(
                    ${pkgs.curl}/bin/curl -fsS -X POST "$hub_url/api/collections/users/auth-with-password" \
                      -H 'Content-Type: application/json' \
                      -d "$(${pkgs.jq}/bin/jq -cn --arg identity ${lib.escapeShellArg adminEmail} --arg password "$USER_PASSWORD" '{identity:$identity,password:$password}')" \
                      | ${pkgs.jq}/bin/jq -r '.token'
                  )"

                  key_tmp="$(mktemp "$STATE_DIRECTORY/id_ed25519.pub.XXXXXX")"
                  ${pkgs.curl}/bin/curl -fsS -H "Authorization: $token" "$hub_url/api/beszel/getkey" \
                    | ${pkgs.jq}/bin/jq -r '.key' > "$key_tmp"
                  chmod 444 "$key_tmp"
                  mv -f "$key_tmp" "$STATE_DIRECTORY/id_ed25519.pub"
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
        beszel-agent-token = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          # Read directly by the agent process (`environmentFile` above), not by systemd itself -
          # same reasoning as `beszel-api.htpasswd`'s own `owner`/`group`, just for the static
          # `beszel-agent` user instead of nginx's. Not `intermediary = true;` - unlike
          # `beszel-password`/`beszel-api-key` (which only ever get read at generation time via
          # a downstream secret's `deps.<name>.file`), this one is ALSO read directly by
          # `beszel-agent.service` on harmony itself via `environmentFile` above, so it needs a
          # real rekeyed copy for harmony - `intermediary` skips producing one, same class of bug
          # `seerr-oidc-client-secret`/`home-assistant-oidc-client-secret` avoid for the same
          # reason.
          group = "beszel-agent";
          owner = "beszel-agent";
          # Handed to Terraform as `beszel_universal_token.${host.name}.token` (my.terranix
          # below) - a genuine RESOURCE ATTRIBUTE Beszel's API has to persist, not read from an
          # env var by the provider itself, so `"variable"` (not `true`) - see
          # modules/terranix.nix's header comment on the two modes.
          settings.terraform = "variable";
        };

        # Beszel's alert notifications are configured entirely through its web UI (Settings >
        # Notifications) using Shoutrrr URL schemas - there's no environment variable, config
        # file, or (per leo-lem/terraform-provider-beszel's own schema - it models `emails` on
        # `user_settings`, nothing for webhook URLs) Terraform resource that reaches them. This
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
          dependencies = { inherit (secrets) beszel-password; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'USER_PASSWORD=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.beszel-password.file})"
            '';
        };

        # Named to match, literally, what leo-lem/terraform-provider-beszel itself reads
        # (BESZEL_PASSWORD - see its own docs) via `settings.terraform = true;` below, not just
        # this repo's own `env-var-for` convention - the provider authenticates to the hub as
        # this same admin account (my.terranix below), so one secret now serves both consumers.
        beszel-password = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = true;
        };

        # Reused from the old netdata.nix - same Discord app, so the primitive secret itself
        # (obtained from Discord's own UI) doesn't need to change, only what derives from it.
        discord-webhook-url = {
          intermediary = true;
          rekeyFile = ../../../secrets/discord-webhook-url.age;
        };
      };

      # Manages the parts of Beszel's setup that DO have a real REST surface -
      # leo-lem/terraform-provider-beszel (an unofficial, single-maintainer, but
      # registry-published and acceptance-tested provider; see its README for what's modeled and
      # why) - closing the "enable/tune alert thresholds" manual step from this aspect's first
      # version. What it can't reach: the hub's own SSH key (beszel-fetch-hub-key.service above)
      # and Discord/webhook notification config (beszel-discord-webhook above) - neither has a
      # resource or route this provider (or, as far as could be found, any other) exposes.
      terranix = { lib, ... }: {
        data.beszel_user.admin.email = adminEmail;

        # `password` isn't set here - the provider reads it from BESZEL_PASSWORD (see that
        # secret's own comment); `endpoint`/`email` aren't secret, so they're set directly
        # rather than round-tripped through an env var, same reasoning as authentik.nix's own
        # `provider.authentik.url`.
        provider.beszel = {
          email = adminEmail;
          endpoint = "http://127.0.0.1:${toString hubPort}";
        };

        resource = {
          # Conservative starting thresholds for a home NAS, not tuned against real data yet -
          # revisit once Beszel has actually been collecting metrics for a while. No ZFS entry:
          # `name`'s documented enum (Status/CPU/Memory/Disk/Temperature/Bandwidth/GPU/
          # LoadAvg1/5/15/Battery) has no ZFS-specific kind, so whether pool-health alerting -
          # the entire reason for this migration (see #772) - is reachable through this
          # resource at all is still unconfirmed; check the hub UI directly once deployed.
          beszel_alert = lib.listToAttrs (
            map
              (
                alert:
                lib.nameValuePair "${host.name}-${alert.name}" (
                  {
                    system = "\${beszel_system.${host.name}.id}";
                    user = "\${data.beszel_user.admin.id}";
                  }
                  // alert
                )
              )
              [
                { name = "Status"; }
                {
                  min = 10;
                  name = "CPU";
                  value = 90;
                }
                {
                  min = 10;
                  name = "Memory";
                  value = 90;
                }
                {
                  min = 10;
                  name = "Disk";
                  value = 90;
                }
                {
                  min = 5;
                  name = "Temperature";
                  value = 80;
                }
              ]
          );

          beszel_system.${host.name} = {
            inherit (host) name;
            host = "127.0.0.1";
            users = [ "\${data.beszel_user.admin.id}" ];
          };

          # Explicit `token` (not left for Beszel to generate, unlike this provider's own
          # getting-started guide) so the exact same value can be handed to the agent's own
          # `environmentFile` above - see `beszel-agent-token`'s own comment for why.
          beszel_universal_token.${host.name} = {
            permanent = true;
            token = "\${var.BESZEL_AGENT_TOKEN}";
            user = "\${data.beszel_user.admin.id}";
          };
        };

        terraform.required_providers.beszel = {
          source = "leo-lem/beszel";
          version = "0.3.0";
        };

        variable.BESZEL_AGENT_TOKEN.sensitive = true;
      };

      virtual-host = {
        inherit global;
        group = "Infra";

        homepage = {
          description = "System monitoring & alerts";
          # No `widget`, unlike netdata.nix's: Homepage's Beszel widget needs a `systemId` that
          # only exists once Terraform has actually applied `beszel_system.${host.name}` above -
          # a value in Terraform's own state, which this static config has no way to read (same
          # gap `beszel_universal_token`'s own comment notes, just in the other direction). Add
          # one by hand later (Settings > Widgets in Homepage's docs) once that id is known, if
          # live stats on the tile are worth it over just linking through.
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
