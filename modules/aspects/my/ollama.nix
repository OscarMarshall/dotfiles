{ den, ... }:
let
  ollamaPort = 11434;
  openWebuiPort = 8080;
in
{
  my.ollama =
    {
      global ? false,
    }:
    { host, ... }: {
      # The Ollama API vhost (machine-to-machine access via HTTP Basic Auth) is a sub-aspect: it
      # needs its own secrets block (api key + derived htpasswd) and a second `virtual-host` entry,
      # which can only be introduced via `includes` since the top level already carries the Open
      # WebUI `virtual-host`. Same split as netdata.nix's main dashboard vs. netdata-api.
      includes = [
        # open-webui is under the "Open WebUI License", which nixpkgs classifies as unfree.
        (den._.unfree [ "open-webui" ])
        {
          # Models are large (3-70 GB each); keep them on the ZFS pool rather than /var on the root
          # filesystem. Owned by the static `ollama` user (see `services.ollama.user` below) - a
          # `DynamicUser` has no fixed name/id to chown a dataset to ahead of time, and
          # `ReadWritePaths` alone only lifts `ProtectSystem`'s read-only mount, not Unix
          # permissions, so a root-owned directory stays unwritable. Its own dataset (rather than a
          # subdirectory of a shared one) since the quirk's `user`/`group` chown the whole thing.
          dataset = {
            group = "ollama";
            name = "ollama";
            pool = "metalminds";
            units = [ "ollama" ];
            user = "ollama";
          };

          secrets = { secrets, ... }: {
            # Raw token - never read by nginx directly; kept as its own secret so its plaintext is
            # retrievable (`agenix decrypt secrets/generated/ollama-api-key.age`) for configuring
            # clients (Continue.dev, OpenCode, scripts, etc.). Same pattern as netdata-api-key.
            ollama-api-key = {
              generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
              intermediary = true;
            };

            "ollama-api.htpasswd" = {
              generator = {
                dependencies = { inherit (secrets) ollama-api-key; };

                # APR1-MD5, not bcrypt: nginx's auth_basic only verifies crypt/APR1-MD5/SHA hashes.
                script =
                  {
                    lib,
                    pkgs,
                    decrypt,
                    deps,
                    ...
                  }:
                  ''
                    printf 'ollama:%s\n' "$(
                      ${pkgs.openssl}/bin/openssl passwd -apr1 "$(${decrypt} ${lib.escapeShellArg deps.ollama-api-key.file})"
                    )"
                  '';
              };

              group = "nginx";
              # nginx's worker process reads this directly for auth_basic_user_file; the default
              # root:root 0400 would cause 500s on every request (same root cause as netdata-api).
              owner = "nginx";
            };
          };

          # Raw Ollama API - OpenAI-compatible endpoint for machine callers (Continue.dev, OpenCode,
          # scripts). HTTP Basic Auth instead of Authentik forward-auth: forward-auth is built around
          # browser session cookies, which machine callers don't carry.
          virtual-host = {
            basicAuthSecret = "ollama-api.htpasswd";
            host = host.name;
            name = "ollama";
            port = ollamaPort;
            # CPU-only inference: a non-streaming completion, or prompt processing on a long input
            # before the first streamed token, easily outlasts nginx's default 60s read timeout.
            proxyTimeout = 900;
          };
        }
      ];

      # Open WebUI writes conversation history and uploaded files here. ZFS dataset on the main
      # pool keeps it off the root filesystem and makes it backup-eligible. Owned by the static
      # `open-webui` user declared below, for the same reason as the `ollama` dataset above.
      dataset = {
        group = "open-webui";
        name = "open-webui";
        pool = "metalminds";
        units = [ "open-webui" ];
        user = "open-webui";
      };

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          services = {
            ollama = {
              enable = true;
              # Explicit cpu variant: harmony has no GPU (no CUDA/ROCm). ollama-cpu is the same as
              # the default `ollama` package on a machine with neither cudaSupport nor rocmSupport
              # enabled, but spelling it out avoids a surprise rebuild if nixpkgs.config ever gains
              # those flags.
              package = pkgs.ollama-cpu;
              group = "ollama";
              # Not loopback, even though nothing outside this host should reach the raw port (the
              # firewall only opens 80/443 - see nginx.nix): on a loopback listener Ollama rejects
              # any request whose Host header isn't localhost/*.local/*.internal with a 403 (its
              # DNS-rebinding guard), which is every request nginx proxies for the `ollama` vhost.
              host = "0.0.0.0";
              modelsDir = "/metalminds/ollama";
              port = ollamaPort;
              # Setting both `user` and `group` makes the module declare them as static system
              # accounts, which systemd then uses in place of allocating a dynamic one (the unit
              # keeps `DynamicUser = true;` and its implied sandboxing) - so the `ollama` dataset
              # above has a fixed owner to chown to.
              user = "ollama";
            };

            open-webui = {
              enable = true;

              environment = {
                ANONYMIZED_TELEMETRY = "False";
                # Trusted-header accounts are created on first visit with this role; Open WebUI's own
                # default (`pending`) would leave everyone but the first user (auto-promoted to admin)
                # locked out until approved by hand, despite already having passed Authentik.
                DEFAULT_USER_ROLE = "user";
                DO_NOT_TRACK = "True";
                # Point at the Ollama backend.
                OLLAMA_BASE_URL = "http://127.0.0.1:${toString ollamaPort}";
                # Disable telemetry (these are the defaults the NixOS module ships, but setting
                # `environment` replaces them, so they must be re-declared here).
                SCARF_NO_ANALYTICS = "True";
                # Log in (and auto-register) whoever Authentik's forward-auth already authenticated,
                # instead of a second, separate Open WebUI account per person - same idea as
                # paperless.nix's HTTP_REMOTE_USER. Safe only because nginx.nix's `protected`
                # location overwrites these headers with Authentik's own values on every request, and
                # Open WebUI listens on loopback only (see `host` below).
                WEBUI_AUTH_TRUSTED_EMAIL_HEADER = "X-authentik-email";
                WEBUI_AUTH_TRUSTED_NAME_HEADER = "X-authentik-name";
              };

              # WEBUI_SECRET_KEY is required and must not be in the Nix store (it signs sessions).
              # Supplied via environmentFile from the decrypted age secret below.
              # systemd reads EnvironmentFile= as root before dropping to the service user, so the
              # default root-owned 0400 permissions are fine - no need for owner = "open-webui".
              environmentFile = config.age.secrets."open-webui.env".path;
              # Bind to loopback only; nginx handles external access.
              host = "127.0.0.1";
              port = openWebuiPort;
              # Open WebUI's state (conversation history, uploaded files, user accounts) lives on the
              # ZFS dataset rather than the default /var/lib/open-webui. The dataset quirk's `units`
              # list ensures the dataset exists (and is chowned) before open-webui.service starts.
              stateDir = "/metalminds/open-webui";
            };
          };

          # Overrides the module's own `DynamicUser = true;` (it has no `user` option, unlike
          # ollama's) - same reasoning as seerr.nix: the `open-webui` dataset above needs a fixed
          # owner. `DynamicUser` also implies `ProtectSystem=strict`, under which the module (which
          # sets no `ReadWritePaths`) couldn't write to a `stateDir` outside /var/lib at all.
          systemd.services.open-webui.serviceConfig = {
            DynamicUser = lib.mkForce false;
            Group = "open-webui";
            User = "open-webui";
          };

          users = {
            groups.open-webui = { };

            users.open-webui = {
              group = "open-webui";
              home = "/metalminds/open-webui";
              isSystemUser = true;
            };
          };
        };

      secrets = { secrets, ... }: {
        open-webui-secret-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
        };

        "open-webui.env" = {
          generator = {
            dependencies = { inherit (secrets) open-webui-secret-key; };

            script =
              {
                lib,
                decrypt,
                deps,
                ...
              }:
              ''
                printf 'WEBUI_SECRET_KEY="%s"\n' "$(
                  ${decrypt} ${lib.escapeShellArg deps.open-webui-secret-key.file}
                )"
              '';
          };

          # open-webui.service reads WEBUI_SECRET_KEY via systemd's EnvironmentFile=, which is
          # processed by the service manager as root before privileges are dropped - the default
          # root-owned 0400 secret permissions are correct here, unlike netdata-secrets.env which
          # is sourced directly by a shell running as the `netdata` user.
        };
      };

      # Open WebUI: full chat interface, protected by Authentik, public DNS record.
      virtual-host = {
        inherit global;
        group = "Infra";

        homepage = {
          description = "Local LLM chat interface";

          widget = {
            mappings = [
              {
                # Homepage's documented way to count an array: `size` returns its length.
                field = "models";
                format = "size";
                label = "Models";
              }
            ];

            type = "customapi";
            url = "http://127.0.0.1:${toString ollamaPort}/api/tags";
          };
        };

        host = host.name;
        icon = "open-webui.svg";
        label = "Open WebUI";
        name = "ai";
        port = openWebuiPort;
        protected = true;
        # Same CPU-inference reasoning as the `ollama` vhost's own `proxyTimeout`.
        proxyTimeout = 900;
        websockets = true;
      };
    };
}
