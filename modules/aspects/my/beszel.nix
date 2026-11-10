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
      administrators,
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
          services = {
            beszel = {
              agent = {
                enable = true;

                environment = {
                  HUB_URL = "http://127.0.0.1:${toString hubPort}";
                  # Written by beszel-fetch-hub-key.service below, once the hub has actually
                  # minted one - see that service's own comment for why this one piece still
                  # can't be done through the Terraform provider (my.terranix below).
                  KEY_FILE = "/var/lib/beszel-agent/id_ed25519.pub";
                  # Netdata's stock `unit_name=!*` matcher (see the old netdata.nix, now removed)
                  # matched nothing by design until overridden - Beszel's own default is unset
                  # (undocumented whether that means "everything" or "nothing"), so this pins it to
                  # the same "watch every unit" intent explicitly rather than relying on a guess.
                  SERVICE_PATTERNS = "*";
                  SYSTEM_NAME = host.name;
                  # `TOKEN_FILE`, not `environmentFile`: the latter wires straight into systemd's
                  # `EnvironmentFile=`, which only parses `KEY=VALUE` lines - `beszel-agent-token`'s
                  # raw `openssl rand -hex 32` output has no `TOKEN=` prefix, so that would leave
                  # `$TOKEN` unset (or fail the file's parse outright). The hub only accepts it once
                  # beszel-agent-register.service below has registered it against Terraform's
                  # `beszel_system`.
                  TOKEN_FILE = config.age.secrets.beszel-agent-token.path;
                };

                smartmon.enable = true;
              };

              hub = {
                enable = true;

                environment = {
                  # Used for links in Beszel's own emails/notifications, not for routing - nginx
                  # still fronts the real traffic.
                  APP_URL = "https://beszel.${host.name}.${host.domain}";
                  # Logs a browser straight into the Beszel account whose email matches the one
                  # Authentik's forward-auth already vouched for (nginx.nix sets this header on every
                  # `protected` request), instead of showing Beszel's own login form. Beszel only
                  # looks the email up, never creates an account for it - each administrator's is
                  # created to match by Terraform (`beszel_user` below). Honored only from loopback,
                  # where nginx is; the hub itself listens on 127.0.0.1 too (the module's default), so
                  # nothing else can reach it to forge the header.
                  TRUSTED_AUTH_HEADER = "X-authentik-email";
                  TRUSTED_PROXY_IPS = "127.0.0.1";
                  USER_EMAIL = adminEmail;
                };

                environmentFile = config.age.secrets."beszel-hub.env".path;
              };
            };

            # The beszel-api vhost also reaches the hub from loopback but skips Authentik (Basic Auth
            # instead - see this aspect's own `includes`), so nothing there overwrites a
            # client-supplied X-authentik-email the way a `protected` vhost does. Blanked, or anyone
            # holding the Basic Auth credential could sign in as any administrator just by sending it.
            nginx.virtualHosts."beszel-api.${host.name}.${host.domain}".locations."/".extraConfig = ''
              proxy_set_header X-authentik-email "";
            '';
          };

          # Only the hub's own SSH public key still needs a raw REST call: it's minted at
          # runtime (nothing to pre-seed via agenix) and, unlike system/alert management
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
              # Deliberately NOT also ordered after beszel-agent-register.service (and so
              # "${host.name}-tf-apply.service", which that waits on) - the upstream module's own
              # `Restart = "on-failure"; RestartSec = "30s";` already retries a rejected token
              # every 30s, the same way terranix.nix's own apply retries a transient failure
              # rather than needing perfect ordering (see its own comment on why ordering alone
              # was never enough there either).
              after = [ "beszel-fetch-hub-key.service" ];
              requires = [ "beszel-fetch-hub-key.service" ];
            };

            # Ties the agent's token to the `beszel_system` Terraform manages - the provider has no
            # resource for the `fingerprints` record that does that. It used to be a universal token
            # instead, but the hub answers a universal token it can't match to a fingerprint by
            # creating a brand-new system of its own, so the agent's first connect landed on an
            # unmanaged duplicate `${host.name}` (invisible to the administrators, holding all the
            # data) while Terraform's stayed empty and down. A per-system token can only ever bind
            # to the system it's registered against: until this has run, the hub just rejects the
            # agent and it retries (see `beszel-agent` above).
            #
            # Wanted by the Terraform apply (not only at boot), since that's what creates the system
            # in the first place. Leaves an existing registration alone, so the fingerprint the hub
            # pinned on the agent's first connect survives.
            beszel-agent-register = {
              description = "Register ${host.name}'s Beszel agent token with its Terraform-managed system";

              wantedBy = [
                "multi-user.target"
                "${host.name}-tf-apply.service"
              ];

              after = [
                "beszel-hub.service"
                "${host.name}-tf-apply.service"
              ];

              requires = [ "beszel-hub.service" ];

              serviceConfig = {
                DynamicUser = true;
                EnvironmentFile = config.age.secrets."beszel-hub.env".path;

                ExecStart = pkgs.writeShellScript "beszel-agent-register" ''
                  set -euo pipefail
                  hub_url="http://127.0.0.1:${toString hubPort}"
                  agent_token="$(< "$CREDENTIALS_DIRECTORY/agent-token")"

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

                  api() {
                    ${pkgs.curl}/bin/curl -fsS -H "Authorization: $token" "$@"
                  }

                  # Only systems the admin account belongs to are visible, and Terraform's always
                  # includes it (`beszel_system` below).
                  mapfile -t systems < <(
                    api -G "$hub_url/api/collections/systems/records" \
                      --data-urlencode ${lib.escapeShellArg "filter=name = '${host.name}'"} \
                      | ${pkgs.jq}/bin/jq -r '.items[].id'
                  )

                  case "''${#systems[@]}" in
                    0)
                      echo "No ${host.name} system yet - Terraform hasn't created it; nothing to register."
                      exit 0
                      ;;
                    1) system="''${systems[0]}" ;;
                    *)
                      echo "Several systems named ${host.name} (''${systems[*]}) - delete all but Terraform's." >&2
                      exit 1
                      ;;
                  esac

                  registered="$(
                    api -G "$hub_url/api/collections/fingerprints/records" \
                      --data-urlencode "filter=system = '$system' && token = '$agent_token'" \
                      | ${pkgs.jq}/bin/jq '.totalItems'
                  )"

                  if [ "$registered" -gt 0 ]; then
                    echo "Agent token already registered with system $system."
                    exit 0
                  fi

                  api -X POST "$hub_url/api/collections/fingerprints/records" \
                    -H 'Content-Type: application/json' \
                    -d "$(${pkgs.jq}/bin/jq -cn --arg system "$system" --arg token "$agent_token" '{system:$system,token:$token,fingerprint:""}')" \
                    >/dev/null
                  echo "Registered agent token with system $system."
                '';

                LoadCredential = "agent-token:${config.age.secrets.beszel-agent-token.path}";
                Type = "oneshot";
              };
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
        data = {
          # Each administrator's email is read off their Authentik account rather than written
          # down here - it has to match what TRUSTED_AUTH_HEADER above receives exactly, and
          # Authentik is where it can change (self-service "Change sign-in email"), so the next
          # apply follows it instead of the login silently breaking.
          authentik_user = lib.genAttrs administrators (username: {
            inherit username;
          });

          beszel_user.admin.email = adminEmail;
        };

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
          #
          # Owned by each administrator rather than the bootstrap admin account: an alert notifies
          # through its owner's own Settings > Notifications, and the administrators are who
          # actually sign in (TRUSTED_AUTH_HEADER above) to fill that in.
          beszel_alert = lib.listToAttrs (
            lib.concatMap (
              username:
              map
                (
                  alert:
                  lib.nameValuePair "${username}-${host.name}-${alert.name}" (
                    {
                      system = "\${beszel_system.${host.name}.id}";
                      user = "\${beszel_user.${username}.id}";
                    }
                    // alert
                  )
                )
                [
                  # `min`/`value` explicit (not left unset, unlike this provider's own docs example
                  # for a Status alert) to route around a real provider bug: Beszel's API always
                  # returns 0 for an alert's unset numeric fields rather than omitting them (or
                  # returning null), and the provider's Read trusts that 0 as a real value - so an
                  # alert created with these genuinely unset comes back holding 0 on the very next
                  # read, which OpenTofu then rejects outright ("Provider produced inconsistent
                  # result after apply ... .min: was null, but now cty.NumberIntVal(0)"). Setting
                  # them to 0 up front makes planned and applied state agree from the start; for a
                  # binary up/down check, 0 reads naturally anyway (no lag, no threshold).
                  {
                    min = 0;
                    name = "Status";
                    value = 0;
                  }
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
            ) administrators
          );

          beszel_system.${host.name} = {
            inherit (host) name;
            host = "127.0.0.1";
            users = [ "\${data.beszel_user.admin.id}" ] ++ map (username: "\${beszel_user.${username}.id}") administrators;
          };

          # The account TRUSTED_AUTH_HEADER above signs each administrator into. Its password is
          # never used (Authentik is the way in), but Beszel requires one - kept in Terraform's own
          # (encrypted) state rather than as an agenix secret, since nothing outside Terraform ever
          # needs to read it.
          beszel_user = lib.genAttrs administrators (username: {
            email = "\${data.authentik_user.${username}.email}";
            password = "\${random_password.beszel-${username}.result}";
            role = "admin";
            verified = true;
          });

          random_password = lib.listToAttrs (
            map (username: lib.nameValuePair "beszel-${username}" { length = 32; }) administrators
          );
        };

        terraform.required_providers = {
          beszel = {
            # Full hostname required, same reasoning (and same fix) as jellyfin.nix's own
            # `registry.terraform.io/ThePhaseless/jellyfin` - OpenTofu's own default registry
            # (registry.opentofu.org, what a bare "leo-lem/beszel" source resolves against)
            # doesn't mirror this provider either: `tofu init` failed outright with "provider
            # registry.opentofu.org/leo-lem/beszel: provider not found" until this was qualified.
            source = "registry.terraform.io/leo-lem/beszel";
            version = "0.3.0";
          };

          random = {
            source = "hashicorp/random";
            version = "3.9.1";
          };
        };
      };

      virtual-host = {
        inherit global;
        group = "Infra";

        homepage = {
          description = "System monitoring & alerts";
          # No `widget`, unlike netdata.nix's: Homepage's Beszel widget needs a `systemId` that
          # only exists once Terraform has actually applied `beszel_system.${host.name}` above -
          # a value in Terraform's own state, which this static config has no way to read. Add
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
