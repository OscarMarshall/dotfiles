# Self-hosted Attic (https://github.com/zhaofengli/attic) binary cache - replaces the old
# `oscarmarshall.cachix.org` Cachix cache as the personal cache every host pulls from (nix.nix) and
# CI pushes to (.github/workflows/*). `global` is effectively required: GitHub Actions runners and
# the off-network hosts (OMARSHAL-M-T2QF, dev203) all need to reach it at the bare
# `attic.<domain>` name, which dns.nix publishes DNS-only (not proxied) - that matters here, since
# Cloudflare's proxy caps request bodies at 100 MB and `attic push` uploads each NAR as one request.
#
# Attic can't import a pre-made signing keypair - the server generates one itself when the cache is
# created - so the cache (and its public key) only exist after a one-time manual bootstrap on the
# host, once this is deployed:
#
#   atticd-atticadm make-token --sub oscar --validity '10y' --pull '*' --push '*' --create-cache '*' \
#     --configure-cache '*' --configure-cache-retention '*' --destroy-cache '*' --delete '*'
#   attic login harmony https://attic.silverlight-nex.us <that token>
#   attic cache create --public oscarmarshall
#   attic cache info oscarmarshall   # -> paste "Public Key" into nix.nix's `atticPublicKey`
#   atticd-atticadm make-token --sub github-actions --validity '10y' --pull oscarmarshall --push oscarmarshall
#                                    # -> the `ATTIC_TOKEN` GitHub Actions secret
{ lib, ... }:
let
  dataDir = "/metalminds/attic";
  port = 8090;
in
{
  my.attic =
    {
      global ? false,
    }:
    { host, ... }: {
      # No `backup`: everything in here is rebuildable from source by definition. The one thing that
      # ISN'T is the cache's signing key (stored in the sqlite DB below) - losing it just means
      # re-running the bootstrap above and updating `atticPublicKey`, not worth offsiting the
      # whole (potentially huge) store for. Owned by the static `atticd` user declared below, same
      # DynamicUser-override reasoning as seerr.nix's own `dataset` field.
      dataset = {
        group = "atticd";
        name = "attic";
        pool = "metalminds";
        units = [ "atticd" ];
        user = "atticd";
      };

      nixos = { config, ... }: {
        services = {
          atticd = {
            enable = true;
            environmentFile = config.age.secrets."atticd.env".path;

            settings = {
              # Used to build the substituter URLs `attic use`/`attic cache info` hand out - without
              # it, atticd derives them from each request's own Host header, which would hand out the
              # host-scoped `attic.harmony.…` name to anyone who happened to connect through it.
              api-endpoint = "https://attic.${host.domain}/";
              database.url = "sqlite://${dataDir}/server.db?mode=rwc";
              # Stale paths are only worth keeping as long as some host might still substitute them -
              # every host here tracks main and garbage-collects its own store after 7 days
              # (nix.nix), so anything a month old is long unreferenced.
              garbage-collection.default-retention-period = "1 month";
              listen = "127.0.0.1:${toString port}";

              storage = {
                path = "${dataDir}/storage";
                type = "local";
              };
            };
          };

          # `client_max_body_size 0` lifts nginx's 1 MB default request-body cap, which every
          # `attic push` of a NAR bigger than that would otherwise hit as a 413. Request buffering
          # off streams uploads straight through instead of spooling multi-GB NARs to disk first.
          nginx.virtualHosts."attic.${host.name}.${host.domain}".extraConfig = ''
            client_max_body_size 0;
            proxy_request_buffering off;
          '';
        };

        # Static user, same reasoning as seerr.nix's own override - the module's
        # `DynamicUser = true;` has no stable identity the `dataset` field above could chown to.
        # `ReadWritePaths` covers the whole dataset rather than just `storage.path` (which the
        # module already allow-lists itself) so sqlite can create its DB and journal files there
        # too, past the module's `ProtectSystem = "strict";`.
        systemd.services.atticd.serviceConfig = {
          DynamicUser = lib.mkForce false;
          ReadWritePaths = [ dataDir ];
        };

        users = {
          groups.atticd = { };

          users.atticd = {
            group = "atticd";
            isSystemUser = true;
          };
        };
      };

      secrets."atticd.env".generator.script = { pkgs, ... }: ''
        printf 'ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=%s\n' "$(
          ${pkgs.openssl}/bin/openssl genrsa -traditional 4096 | ${pkgs.coreutils}/bin/base64 -w0
        )"
      '';

      virtual-host = {
        inherit global port;
        host = host.name;
        label = "Attic";
        name = "attic";
        # Large NAR uploads can outlast nginx's default 60s proxy timeouts.
        proxyTimeout = 600;
      };
    };
}
