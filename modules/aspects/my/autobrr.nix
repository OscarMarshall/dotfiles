{
  my.autobrr =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 7474;
    in
    {
      nixos = { config, ... }: {
        services.autobrr = {
          enable = true;

          settings = {
            inherit port;
            checkForUpdates = true;
            host = "127.0.0.1";
            # Must equal this vhost's own `name` below - authentik.nix sets the OAuth2
            # provider's `client_id` to `vh.name` for every `oidc`-tagged host, unconditionally.
            oidcClientId = "autobrr";
            # Authentik is the only way in, same as before - just via OIDC now rather than
            # forward-auth. No fallback login form worth keeping here, unlike home-assistant.nix:
            # nothing breaks for anyone if autobrr's UI is briefly unreachable.
            oidcDisableBuiltInLogin = true;
            # autobrr's own login can't be handed off to Authentik's forward-auth the way the
            # *arrs' `auth.method = "External"` does (sonarr.nix) - its session middleware only
            # ever trusts its own cookie or an API key, never a proxy header - so sitting behind
            # `protected` just stacked autobrr's login form behind Authentik's. Native OIDC
            # against Authentik is its only way to skip that form. Client secret is NOT here:
            # this TOML lands in the world-readable store - see `systemd.services.autobrr`.
            oidcEnabled = true;
            # Trailing slash matters: go-oidc requires this to match the discovery document's
            # `issuer` byte for byte, and Authentik's carries one (same as immich.nix's own).
            oidcIssuer = "https://${config.services.authentik.nginx.host}/application/o/autobrr/";
            # Single-valued, unlike the provider's own redirect URIs (authentik.nix registers
            # one per hostname) - pinned to the host-qualified name, which every instance of
            # this aspect answers on regardless of `global`.
            oidcRedirectUrl = "https://autobrr.${host.name}.${host.domain}/api/auth/oidc/callback";
          };
        };

        # autobrr reads any `AUTOBRR__<KEY>` env var from a file when suffixed `_FILE` (its
        # config.go `GetEnvStr`), so the secret goes straight from LoadCredential to autobrr
        # with no templating step - upstream's module runs it under DynamicUser, which
        # LoadCredential handles without any user/group plumbing. `%d` is the unit's
        # credentials directory, expanded by systemd itself.
        systemd.services.autobrr = {
          environment.AUTOBRR__OIDC_CLIENT_SECRET_FILE = "%d/oidc-client-secret";
          serviceConfig.LoadCredential = "oidc-client-secret:${config.age.secrets.autobrr-oidc-client-secret.path}";
        };
      };

      # Same shape as immich-oidc-client-secret/seerr-oidc-client-secret: dual-use, fed to
      # Authentik as a Terraform `variable` (authentik.nix's `oidc`-tagged
      # `authentik_provider_oauth2`) AND read by autobrr itself above, so not `intermediary`.
      secrets.autobrr-oidc-client-secret = {
        generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
        settings.terraform = "variable";
      };

      # No `homepage` block: deliberately not a dashboard tile, but `icon`/`group` still feed its
      # Authentik application (see virtual-host.nix). No `label` either - "autobrr" IS the brand's
      # own styling.
      virtual-host = {
        inherit global port;
        group = "Arr Stack";
        host = host.name;
        icon = "https://raw.githubusercontent.com/autobrr/autobrr/develop/web/src/logo.svg";
        name = "autobrr";

        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) in
        # place of the old `protected = true` - see `settings` above for why forward-auth didn't
        # work here. Callback path is autobrr's own `/api/auth/oidc/callback` route.
        oidc = {
          client-secret = "autobrr-oidc-client-secret";
          redirect-paths = [ "/api/auth/oidc/callback" ];
        };
      };
    };
}
