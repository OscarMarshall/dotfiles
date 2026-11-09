{
  my.profilarr =
    {
      global ? false,
    }:
    { host, ... }:
    let
      # Matches virtual-host.nix's own derived hostname (`${name}.${host.name}.<domain>`) - no
      # shared domain constant exists in this repo (authentik.nix/dns.nix/nginx.nix each carry this
      # same literal), so this matches that convention rather than introducing one.
      domain = "silverlight-nex.us";
      port = 6868;
    in
    {
      dataset = {
        name = "profilarr";
        pool = "metalminds";
        units = [ "podman-profilarr" ];
      };

      nixos = { config, ... }: {
        virtualisation.oci-containers.containers.profilarr = {
          environment = {
            # Profilarr only reaches this vhost via nginx (its port is bound to loopback only),
            # and every such request already passed the Authentik forward-auth gate in front of it
            # - so Profilarr's own login is pure redundancy, same as radarr.nix's/prowlarr.nix's
            # `auth.method = "External"`. v1 had no way to turn its login off at all (every /api
            # call demanded its own session cookie or API key, and the frontend showed the login
            # page on any 401), which is why this moved to v2: `AUTH=off` is v2's real, supported
            # switch for exactly this, leaving Authentik as the sole gate.
            AUTH = "off";
            # v2 is a SvelteKit app, whose CSRF check rejects form POSTs whose Origin doesn't
            # match the URL it thinks it's served from - behind nginx that's `http://127.0.0.1`
            # unless told otherwise.
            ORIGIN = "https://profilarr.${host.name}.${domain}";
            TZ = config.time.timeZone;
          };

          # v2 lives on GHCR only - the Docker Hub `santiagosayshey/profilarr` repo v1 came from
          # stops at v1.1.5, which is why Renovate never offered this upgrade. v2 is a rewrite that
          # can't read v1's data, so it starts from scratch (re-link the database and Arr
          # instances in its onboarding). Its files (`/config/{data,logs,backups,databases}`) don't
          # collide with v1's (`/config/{profilarr.db,db,log}`), so v1's are left in place on the
          # same dataset for rollback, and can be deleted once v2 is set up. The optional
          # `profilarr-parser` sidecar (only needed for custom format/quality profile testing) is
          # left out.
          image = "ghcr.io/dictionarry-hub/profilarr:2.3.1@sha256:352e42dec74ecfd68d13bb198fbc6d9346e3a8c55003026e1814e59319a2176d";

          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];

          volumes = [ "/metalminds/profilarr:/config" ];
        };
      };

      virtual-host = {
        inherit global port;
        group = "Arr Stack";
        homepage.description = "Radarr/Sonarr custom format manager";
        host = host.name;
        icon = "https://raw.githubusercontent.com/Dictionarry-Hub/profilarr/develop/src/lib/client/assets/logo-512.png";
        label = "Profilarr";
        name = "profilarr";
        protected = true;
      };
    };
}
