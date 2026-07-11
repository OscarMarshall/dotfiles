{ lib, ... }:
let
  url = "immich.harmony.silverlight-nex.us";
  port = 2283;
in
{
  my.immich = { administrators }: {
    virtual-host = {
      name = "immich";
      inherit url port;
    };

    homepage-entry = {
      group = "Media";
      label = "Immich";
      description = "Photo & video backup";
      href = "https://${url}";
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
