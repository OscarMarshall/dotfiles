# Web UI for my.headscale (nodes, users, preauth keys, ACL policy). headscale's own config lives in
# the Nix store, so Headplane shows it read-only - Nix stays the source of truth for that; everything
# headscale keeps in its database instead (nodes, users, keys, a DB-mode policy) is fully editable.
#
# Login is Authentik forward-auth (`protected` below) with Headplane trusting the identity headers
# nginx.nix sets from it (`proxy_auth`), rather than Headplane's own OIDC client - one fewer
# Authentik app and client secret, same pattern as every other `protected` service. Only loopback
# may supply those headers (proxy_auth's default CIDRs), and Headplane only listens on loopback, so
# they can't be forged from outside nginx.
{
  my.headplane =
    { host, ... }:
    let
      port = 3000;
      url = "headplane.${host.name}.${host.domain}";
    in
    {
      nixos = { config, pkgs, ... }: {
        services = {
          headplane = {
            enable = true;

            settings = {
              headscale.api_key_path = "/var/lib/headplane-api-key/api-key";

              server = {
                inherit port;
                cookie_secret_path = config.age.secrets.headplane-cookie-secret.path;
                host = "127.0.0.1";

                proxy_auth = {
                  email_header = "X-authentik-email";
                  enabled = true;
                  name_header = "X-authentik-name";
                  user_header = "X-authentik-uid";
                };
              };
            };
          };

          # Headplane only serves under /admin; send the bare host (the Homepage tile's link) there.
          nginx.virtualHosts.${url}.locations."= /".return = "302 /admin/";
        };

        # Headplane needs a headscale API key for every API call it makes on a proxy-authenticated
        # user's behalf. Those can only be minted by headscale itself, so this does it on the box:
        # a 10-year key, kept until it's revoked, expired, or within 30 days of expiring, at which
        # point a fresh one replaces it and the old one is expired. Runs as headscale (same user
        # Headplane runs as - see its module) so the CLI can reach headscale's socket and Headplane
        # can read the file.
        systemd.services.headplane-api-key = {
          after = [ "headscale.service" ];
          before = [ "headplane.service" ];

          path = [
            config.services.headscale.package
            pkgs.jq
          ];

          requiredBy = [ "headplane.service" ];
          requires = [ "headscale.service" ];

          script = ''
            file="$STATE_DIRECTORY/api-key"

            # headscale's CLI socket appears a moment after the unit is marked started.
            for _ in $(seq 30); do
              if headscale apikeys list >/dev/null 2>&1; then break; fi
              sleep 1
            done

            # `apikeys list` only shows a key's "hskey-api-<12-char id>" prefix.
            old=
            if [ -s "$file" ]; then
              old=$(head -c 22 "$file")
              expires=$(headscale apikeys list -o json | jq --arg p "$old" '[.[] | select(.prefix | startswith($p)) | .expiration.seconds][0] // 0')
              if [ "$expires" -gt $(($(date +%s) + 30 * 86400)) ]; then exit 0; fi
            fi

            umask 077
            headscale apikeys create --expiration 87600h | tr -d '\n' > "$file.new"
            mv "$file.new" "$file"
            if [ -n "$old" ]; then headscale apikeys expire --prefix "$old" --force; fi
          '';

          serviceConfig = {
            Group = config.services.headscale.group;
            StateDirectory = "headplane-api-key";
            StateDirectoryMode = "0700";
            Type = "oneshot";
            User = config.services.headscale.user;
          };
        };
      };

      # Headplane requires exactly 32 characters, so no trailing newline.
      secrets.headplane-cookie-secret = {
        generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16 | tr -d '\\n'";
        owner = "headscale";
      };

      virtual-host = {
        inherit port;
        group = "Infra";
        homepage.description = "Headscale admin";
        host = host.name;
        icon = "headplane.svg";
        label = "Headplane";
        name = "headplane";
        protected = true;
      };
    };
}
