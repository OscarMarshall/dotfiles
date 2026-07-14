let
  url = "seerr.harmony.silverlight-nex.us";
  port = 5055;
  authentikUrl = "auth.harmony.silverlight-nex.us";

  # Seerr has no released OIDC support yet (seerr-team/seerr#2715 is still open). Build from
  # michaelhthomas's PR branch until it lands in a release, then drop this override.
  oidcFork = {
    owner = "michaelhthomas";
    repo = "seerr";
    rev = "0078a482c9e2a1144069af5d196660e392940ea0";
    hash = "sha256-JchL4DJk/DrveZthiawtNJW2tDtr66e3k+EaS+iPJp8=";
  };
in
{
  my.seerr = {
    virtual-host = {
      name = "seerr";
      inherit url port;
    };

    homepage-entry = {
      group = "Media";
      label = "Seerr";
      description = "Media requests";
      href = "https://${url}";
    };

    secrets = {
      seerr-oidc-client-secret.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
    };

    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        package = pkgs.seerr.overrideAttrs (old: rec {
          pname = "seerr";
          version = "unstable-2026-07-12";

          src = pkgs.fetchFromGitHub {
            inherit (oidcFork)
              owner
              repo
              rev
              hash
              ;
          };

          pnpmDeps = pkgs.fetchPnpmDeps {
            inherit pname version src;
            pnpm = pkgs.pnpm_10.override { nodejs-slim = pkgs.nodejs-slim_22; };
            fetcherVersion = 3;
            hash = "sha256-7nBkeXGJfDRSvNesOjOK+Mtzp6SlBvbytyfsQl9eh/Y=";
          };
        });

        # Seerr's OIDC settings have no env-var equivalent yet — only settings.json. Merge our
        # provider config into it on every start, preserving whatever else is already there (the
        # app itself owns the rest of the file).
        configureOidc = pkgs.writeShellApplication {
          name = "seerr-configure-oidc";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.jq
          ];
          text = ''
            settings="$CONFIG_DIRECTORY/settings.json"
            mkdir -p "$(dirname "$settings")"
            existing="{}"
            [ -f "$settings" ] && existing="$(cat "$settings")"
            client_secret="$(cat "$CREDENTIALS_DIRECTORY/oidc-client-secret")"
            jq -n \
              --argjson existing "$existing" \
              --arg secret "$client_secret" \
              '(($existing.oidc.providers // []) | map(select(.slug != "authentik"))) as $others
              | $existing * {
                main: { oidcLogin: true },
                oidc: {
                  providers: ($others + [{
                    slug: "authentik",
                    name: "Authentik",
                    issuerUrl: "https://${authentikUrl}/application/o/seerr/",
                    clientId: "seerr",
                    clientSecret: $secret,
                    scopes: "openid profile email",
                    newUserLogin: true
                  }])
                }
              }' >"$settings.tmp"
            mv "$settings.tmp" "$settings"
          '';
        };
      in
      {
        services.seerr = {
          enable = true;
          inherit port package;
        };

        systemd.services.seerr.serviceConfig = {
          LoadCredential = "oidc-client-secret:${config.age.secrets.seerr-oidc-client-secret.path}";
          ExecStartPre = [ (lib.getExe configureOidc) ];
        };
      };
  };
}
