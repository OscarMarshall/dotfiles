let

  port = 5055;

  # Seerr has no released OIDC support yet (seerr-team/seerr#2715 is still open). Build from
  # michaelhthomas's PR branch until it lands in a release, then drop this override.
  oidcFork = {
    hash = "sha256-JchL4DJk/DrveZthiawtNJW2tDtr66e3k+EaS+iPJp8=";
    owner = "michaelhthomas";
    repo = "seerr";
    rev = "0078a482c9e2a1144069af5d196660e392940ea0";
  };
in
{
  my.seerr =
    {
      global ? false,
    }:
    { host, ... }: {
      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          package = pkgs.seerr.overrideAttrs (old: rec {
            pname = "seerr";
            pnpmDeps = pkgs.fetchPnpmDeps {
              inherit pname version src;
              fetcherVersion = 3;
              hash = "sha256-7nBkeXGJfDRSvNesOjOK+Mtzp6SlBvbytyfsQl9eh/Y=";
              pnpm = pkgs.pnpm_10.override { nodejs-slim = pkgs.nodejs-slim_22; };
            };
            src = pkgs.fetchFromGitHub {
              inherit (oidcFork)
                owner
                repo
                rev
                hash
                ;
            };
            version = "unstable-2026-07-12";
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
                      issuerUrl: "https://${config.services.authentik.nginx.host}/application/o/seerr/",
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
            inherit port package;
            enable = true;
          };

          systemd.services.seerr.serviceConfig = {
            ExecStartPre = [ (lib.getExe configureOidc) ];
            LoadCredential = "oidc-client-secret:${config.age.secrets.seerr-oidc-client-secret.path}";
          };
        };
      # `settings.terraform = "variable";` feeds a Terraform `variable` (modules/terranix.nix's two
      # modes); also read directly below (LoadCredential) by `configureOidc`, so it's NOT
      # `intermediary` - it has to be materialized as a real host secret too.
      secrets = {
        seerr-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          settings.terraform = "variable";
        };
      };
      virtual-host = {
        inherit port global;
        group = "Media";
        homepage = {
          description = "Media requests";
        };
        host = host.name;
        icon = "seerr.svg";
        label = "Seerr";
        name = "seerr";
        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Redirect paths per the OIDC setup docs for
        # this exact fork revision (docs/using-seerr/settings/users/oidc.md at `oidcFork.rev`
        # above).
        oidc = {
          client-secret = "seerr-oidc-client-secret";
          redirect-paths = [
            "/login"
            "/profile/settings/linked-accounts"
          ];
        };
      };
    };
}
