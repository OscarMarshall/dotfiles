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
        {
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
          };
        }
      ];

      # Open WebUI writes conversation history and uploaded files here. ZFS dataset on the main
      # pool keeps it off the root filesystem and makes it backup-eligible.
      dataset = {
        name = "llm";
        pool = "metalminds";

        units = [
          "open-webui"
          "ollama"
        ];
      };

      nixos = { config, pkgs, ... }: {
        services = {
          ollama = {
            enable = true;
            # Explicit cpu variant: harmony has no GPU (no CUDA/ROCm). ollama-cpu is the same as the
            # default `ollama` package on a machine with neither cudaSupport nor rocmSupport enabled,
            # but spelling it out avoids a surprise rebuild if nixpkgs.config ever gains those flags.
            package = pkgs.ollama-cpu;
            # Bind to all interfaces so LAN clients can hit port 11434 directly without going
            # through nginx - useful for apps that talk to Ollama natively (Obsidian, VS Code
            # extensions, etc.). The API is unauthenticated on the raw port; if that's a concern, set
            # host to "127.0.0.1" and require clients to go through the nginx vhost with Basic Auth.
            host = "0.0.0.0";
            # Models are large (3-70 GB each); keep them on the ZFS pool rather than /var on the
            # root filesystem. The `llm` dataset's `units` list above ensures it's mounted before
            # ollama.service starts.
            modelsDir = "/metalminds/llm/models";
            port = ollamaPort;
          };

          open-webui = {
            enable = true;

            environment = {
              ANONYMIZED_TELEMETRY = "False";
              DO_NOT_TRACK = "True";
              # Point at the Ollama backend.
              OLLAMA_BASE_URL = "http://127.0.0.1:${toString ollamaPort}";
              # Disable telemetry (these are the defaults the NixOS module ships, but setting
              # `environment` replaces them, so they must be re-declared here).
              SCARF_NO_ANALYTICS = "True";
            };

            # WEBUI_SECRET_KEY is required and must not be in the Nix store (it signs sessions).
            # Supplied via environmentFile from the decrypted age secret below.
            environmentFile = config.age.secrets."open-webui.env".path;
            # Bind to loopback only; nginx handles external access.
            host = "127.0.0.1";
            port = openWebuiPort;
            # Open WebUI's state (conversation history, uploaded files, user accounts) lives on the
            # ZFS dataset. The service's DynamicUser means it can't write to an arbitrary path unless
            # the directory already exists with the right ownership; the dataset quirk handles that.
            stateDir = "/metalminds/llm/open-webui";
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

          # open-webui.service runs as the `open-webui` user (DynamicUser); systemd's
          # EnvironmentFile= requires the service's user to be able to read the file. The agenix
          # default of root:root 0400 would silently fail to load the env (same class of bug as
          # netdata-secrets.env needing owner = "netdata").
          owner = "open-webui";
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
                field.models = "length";
                format = "number";
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
        websockets = true;
      };
    };
}
