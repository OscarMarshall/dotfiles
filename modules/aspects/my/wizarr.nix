let
  port = 5690;
in
{
  my.wizarr =
    {
      global ? false,
    }:
    { host, ... }: {
      dataset = {
        name = "wizarr";
        pool = "metalminds";
        units = [ "podman-wizarr" ];
      };

      nixos = { config, ... }: {
        virtualisation.oci-containers.containers.wizarr = {
          environment = {
            # Authentik's forward-auth (`protected` below) already gates every path except the
            # public invite ones (`bypassAuthPaths`) - Wizarr's own login would be pure redundancy
            # for the admin panel and would otherwise block the whole point of the public invite
            # flow, so it's turned off entirely rather than left to coexist with forward-auth.
            DISABLE_BUILTIN_AUTH = "true";
            TZ = config.time.timeZone;
          };

          # Pinned to the current "v2026.7.1" tag's amd64 digest - re-resolve if bumping:
          #   curl -sH "Authorization: Bearer $(curl -s 'https://ghcr.io/token?scope=repository:wizarrrr/wizarr:pull' | jq -r .token)" \
          #     -H "Accept: application/vnd.oci.image.index.v1+json" \
          #     https://ghcr.io/v2/wizarrrr/wizarr/manifests/<tag> | jq -r '.manifests[] | select(.platform.architecture == "amd64") | .digest'
          image = "ghcr.io/wizarrrr/wizarr:v2026.7.1@sha256:be7087954f92badb16248073a347aadc771577a98c9c0c16b4cc010b143bbf50";

          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];

          volumes = [ "/metalminds/wizarr:/data" ];
        };
      };

      virtual-host = {
        inherit global port;

        # Invite links have to work for people who don't have an Authentik account yet (the whole
        # point of Wizarr), so its public join/onboarding routes and the static assets they need
        # bypass the forward-auth gate below - matching the "important!" whitelist Wizarr's own
        # reverse-proxy docs call out for exactly this setup (Authelia/Authentik in front).
        bypassAuthPaths = [
          "^/j(oin)?(/.*)?"
          "^/static(/.*)?"
          "^/setup(/.*)?"
          "^/wizard(/.*)?"
          "^/image-proxy(/.*)?"
          "^/cinema-posters(/.*)?"
        ];

        group = "Infra";
        homepage.description = "Plex invite management";
        host = host.name;
        icon = "wizarr.svg";
        label = "Wizarr";
        name = "wizarr";
        protected = true;
      };
    };
}
