let
  port = 8123;
in
{
  my.home-assistant =
    {
      global ? false,
    }:
    { host, ... }: {
      # Owned by Home Assistant's own native NixOS service user/group (`hass`, hardcoded by
      # upstream's module rather than exposed as an option) - zfs.nix's generic `dataset`-quirk
      # consumer chowns it once created, and `units` orders the `home-assistant` unit after that
      # (avoids it starting before this exists/is mounted - see immich.nix's own comment on why
      # that's a real risk).
      dataset = {
        backup = true;
        group = "hass";
        name = "home-assistant";
        pool = "metalminds";
        units = [ "home-assistant" ];
        user = "hass";
      };

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          services.home-assistant = {
            config = {
              # Deliberately no `features.default_redirect`, unlike Immich's `oauth.autoLaunch`/
              # Nextcloud's `hide_login_form` - auth_oidc's own default renders a "Log in with
              # Authentik" button ALONGSIDE Home Assistant's native login form, rather than
              # replacing it. Worth keeping both here specifically: unlike a media app, losing
              # smart-home control the moment Authentik is unreachable is a real cost, so the
              # native fallback stays reachable without a special escape-hatch URL the way
              # Nextcloud/Immich need one.
              auth_oidc = {
                # Must equal this vhost's own `name` below - authentik.nix sets the OAuth2
                # provider's `client_id` to `vh.name` for every `oidc`-tagged host, unconditionally.
                client_id = "home-assistant";
                # Real value lives in the generated `home-assistant-secrets` age secret (see
                # `secrets`, below), never in this world-readable Nix store path - this repo's own
                # remote is public, unlike every other value on this page. `!secret <key>` is Home
                # Assistant's own YAML tag (its rendering module unquotes a leading-bang string like
                # this one specifically so it survives as a literal tag, not a string) - it reads
                # `<key>` out of a `secrets.yaml` dropped into `configDir` at every start
                # (`systemd.services.home-assistant`, below), the same file Home Assistant's own
                # docs recommend for exactly this.
                client_secret = "!secret oidc_client_secret";
                discovery_url = "https://${config.services.authentik.nginx.host}/application/o/home-assistant/.well-known/openid-configuration";
              };

              # Enables the same integration bundle (frontend, backup, mobile_app, updater, etc.)
              # a fresh, non-Nix install onboards with by default - without this key, none of it
              # loads at runtime even though `extraComponents`' own default already bundles its
              # dependencies into the package.
              default_config = { };

              homeassistant = {
                # Real values live in the same generated `secrets.yaml` as `auth_oidc.client_secret`
                # above - see its own comment for why.
                latitude = "!secret latitude";
                longitude = "!secret longitude";
                name = "Home";
                unit_system = "us_customary";
              };

              http = {
                # Only nginx (below) ever needs to reach this - matches immich.nix's own
                # `host = "127.0.0.1"` reasoning for pinning a backend that's exclusively reached
                # through the reverse proxy.
                server_host = "127.0.0.1";
                server_port = port;
                # Required for a reverse-proxied Home Assistant: without both of these, every
                # request arrives looking like it came from nginx's own loopback address, and
                # Home Assistant rejects it outright ("Blocked login attempt from untrusted
                # proxy").
                trusted_proxies = [ "127.0.0.1" ];
                use_x_forwarded_for = true;
              };
            };

            enable = true;
            configDir = "/metalminds/home-assistant";
            # Authentik's own integration guide for Home Assistant
            # (integrations.goauthentik.io/miscellaneous/home-assistant) points at this - a real
            # OIDC login (config_flow-based, minimal core patching per its own README), not
            # forward-auth. nixpkgs already packages it (`home-assistant-custom-components.auth_oidc`,
            # built straight from upstream's own release tag, Tailwind CSS step included), so this
            # is just a customComponent + config block away, same shape as any other
            # `services.home-assistant.customComponents` entry.
            customComponents = [ pkgs.home-assistant-custom-components.auth_oidc ];
          };

          # LoadCredential (rather than a plain `EnvironmentFile`/config-templating generator, the
          # usual pattern elsewhere in this repo) because the secret's own content already IS
          # valid `secrets.yaml` - dropping it in verbatim is simpler than parsing it apart into
          # named values just to reassemble the same file. Runs as the `hass` user (this preStart
          # addition inherits `serviceConfig.User` from upstream's own module, same as every other
          # ExecStartPre here), so no chown is needed. `lib.mkAfter`: `preStart` is `types.lines`,
          # concatenated in `mkOrder` priority order, not declaration order - this only needs to
          # land somewhere after upstream's own directory setup, not before it.
          systemd.services.home-assistant = {
            preStart = lib.mkAfter ''
              install -m600 "$CREDENTIALS_DIRECTORY/secrets.yaml" "${config.services.home-assistant.configDir}/secrets.yaml"
            '';

            serviceConfig.LoadCredential = "secrets.yaml:${config.age.secrets.home-assistant-secrets.path}";
          };
        };

      secrets = { secrets, ... }: {
        # Two external values this repo can't generate (they're wherever the house actually
        # is), so - like qbittorrent.nix's own ProtonVPN config - each is authored by hand
        # rather than via a `generator`: `agenix edit secrets/home-assistant-latitude.age` /
        # `secrets/home-assistant-longitude.age` (bare numbers, no YAML key), then
        # `agenix rekey -a`. `intermediary` because nothing reads either directly - only the
        # generator below, which folds both into the actual `secrets.yaml` Home Assistant's
        # `!secret` tags (above) read.
        home-assistant-latitude = {
          intermediary = true;
          rekeyFile = ../../../secrets/home-assistant-latitude.age;
        };

        home-assistant-longitude = {
          intermediary = true;
          rekeyFile = ../../../secrets/home-assistant-longitude.age;
        };

        # Unlike the two above, this one this repo CAN generate - same shape as
        # immich-oidc-client-secret/nextcloud-oidc-client-secret/seerr-oidc-client-secret.
        # `settings.terraform = "variable";` (not `intermediary`) because it's dual-use: fed to
        # Authentik as a Terraform `variable` (authentik.nix's `oidc`-tagged
        # `authentik_provider_oauth2`), AND read directly by the generator below.
        home-assistant-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          settings.terraform = "variable";
        };

        home-assistant-secrets.generator = {
          dependencies = {
            inherit (secrets) home-assistant-latitude home-assistant-longitude home-assistant-oidc-client-secret;
          };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'latitude: %s\n' "$(${decrypt} ${lib.escapeShellArg deps.home-assistant-latitude.file})"
              printf 'longitude: %s\n' "$(${decrypt} ${lib.escapeShellArg deps.home-assistant-longitude.file})"
              printf 'oidc_client_secret: %s\n' "$(${decrypt} ${lib.escapeShellArg deps.home-assistant-oidc-client-secret.file})"
            '';
        };
      };

      virtual-host = {
        inherit global port;
        group = "Infra";
        homepage.description = "Home automation";
        host = host.name;
        icon = "home-assistant.svg";
        label = "Home Assistant";
        name = "home-assistant";

        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Deliberately NOT `protected`
        # (forward-auth): auth_oidc (above) does its own login against Authentik instead, which -
        # unlike forward-auth - leaves Home Assistant's native login form in place as a fallback
        # (see the `config.auth_oidc` comment above for why that matters here specifically).
        oidc = {
          client-secret = "home-assistant-oidc-client-secret";
          redirect-paths = [ "/auth/oidc/callback" ];
        };

        websockets = true;
      };
    };
}
