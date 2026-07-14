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
        homepage = {
          group = "Media";
          label = "Immich";
          description = "Photo & video backup";
        };
      };

      secrets = {
        immich-oidc-client-secret.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
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
          settings.oauth = {
            enabled = true;
            issuerUrl = "https://auth.harmony.silverlight-nex.us/application/o/immich/";
            clientId = "immich";
            clientSecret._secret = config.age.secrets.immich-oidc-client-secret.path;
            scope = "openid email profile";
            mobileOverrideEnabled = true;
            mobileRedirectUri = "https://${url}/api/oauth/mobile-redirect";
          };
        };
      };
    };
}
