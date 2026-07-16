{ lib, ... }:
let
  domain = "silverlight-nex.us";
  port = 2283;
in
{
  my.immich =
    {
      administrators,
      global ? false,
    }:
    { host, ... }:
    let
      url = "immich.${host.name}.${domain}";
    in
    {
      virtual-host = {
        name = "immich";
        host = host.name;
        inherit port global;
        # Immich's frontend opens a WebSocket right after login for real-time updates (job
        # progress, live sync); without this the connection silently fails and the UI hangs.
        websockets = true;
        # Immich sets its own secure/HttpOnly/SameSite flags on its session cookie. Without this,
        # nginx's blanket cookie rewrite appends a second, duplicate set of those flags, producing
        # a malformed Set-Cookie the browser silently refuses to store — login succeeds
        # server-side but the session never sticks, so the UI hangs forever waiting for one that
        # never arrives.
        preserveCookieFlags = true;
        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Per Immich's own OIDC docs
        # (docs.immich.app/administration/oauth) - web login redirects to `/auth/login`, the "link
        # another device" flow redirects to `/user-settings`, and the mobile app comes in through
        # the HTTPS override below (`mobileRedirectUri`) rather than its native
        # `app.immich:///oauth-callback` scheme, which Authentik doesn't need to know about as a
        # result.
        oidc = {
          redirect-paths = [
            "/auth/login"
            "/user-settings"
            "/api/oauth/mobile-redirect"
          ];
          client-secret = "immich-oidc-client-secret";
        };
        label = "Immich";
        icon = "immich.svg";
        group = "Media";
        homepage = {
          description = "Photo & video backup";
        };
      };

      # `settings.terraform = "variable";` (not just any secret) - it now feeds a Terraform
      # `variable` (modules/terranix.nix's two modes) as well as Immich's own `environmentFile`-
      # style secret consumption below, so it's NOT `intermediary` - unlike a secret that ONLY ever
      # feeds a Terraform `variable`, this one is ALSO read directly by `services.immich` below via
      # its own decrypted file, so it has to be materialized as a real host secret.
      secrets = {
        immich-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          settings.terraform = "variable";
        };
      };

      nixos = { config, ... }: {
        users.users = lib.genAttrs administrators (user: {
          extraGroups = [ "immich" ];
        });

        services.immich = {
          enable = true;
          host = "127.0.0.1";
          inherit port;
          mediaLocation = "/metalminds/pictures";
          settings = {
            oauth = {
              enabled = true;
              issuerUrl = "https://${config.services.authentik.nginx.host}/application/o/immich/";
              clientId = "immich";
              clientSecret._secret = config.age.secrets.immich-oidc-client-secret.path;
              scope = "openid email profile";
              mobileOverrideEnabled = true;
              mobileRedirectUri = "https://${url}/api/oauth/mobile-redirect";
            };
            # Authentik is the only way in; Immich's own local accounts can no longer be used.
            # Immich attaches an OAuth login to an existing account by EMAIL (its auth service
            # looks the user up with `getByEmail`, then stamps the `oauthId` onto that row), so
            # whoever administers this has to carry the same address in Authentik as on their
            # Immich account - otherwise `autoRegister` (on by default, not set here) quietly
            # makes them a SECOND, non-admin user instead of logging them into the existing one.
            #
            # Not a lockout risk despite that: `services.immich.settings` being set at all puts
            # Immich in config-file mode, where the admin UI can't override any of this anyway, so
            # the way back is flipping this line and rebuilding - not clicking through a UI that
            # would refuse anyway.
            passwordLogin.enabled = false;
          };
        };
      };
    };
}
