let
  # Same VPN-Confinement bridge address as qbittorrent.nix's own pinned `namespaceAddress` (same
  # `proton0` namespace) - pinned here too rather than reached via `config`, for the same reason
  # qbittorrent.nix gives: this is referenced from `virtual-host`'s `upstreamHost` below, a scope
  # that doesn't have it.
  namespaceAddress = "192.168.15.1";
  port = 5010;
in
{
  my.mousehole =
    { host, ... }:
    let
      hostname = "mousehole.${host.name}.${host.domain}";
    in
    {
      dataset = {
        name = "mousehole";
        pool = "metalminds";
        units = [ "podman-mousehole" ];
      };

      nixos = { config, ... }: {
        virtualisation.oci-containers.containers.mousehole = {
          environment = {
            # Reverse-proxied by nginx at `hostname` (not one of the localhost-only defaults), so
            # both allowlists need that name added - see the project's own security guide
            # (docs/security-guide.md#reverse-proxy).
            MOUSEHOLE_ALLOWED_HOSTS = "localhost,127.0.0.1,[::1],${hostname}";
            MOUSEHOLE_ALLOWED_ORIGINS = "https://${hostname}";
            # Same reasoning as qbittorrent.nix's own `AuthSubnetWhitelistEnabled`: this container
            # is reachable from outside the `proton0` namespace ONLY via `namespaceAddress`, which
            # is itself only reachable from harmony's own default netns (i.e. nginx) - already
            # authenticated by Authentik's forward-auth (`protected` below) before it ever gets
            # here. Mousehole has no subnet-scoped equivalent of `AuthSubnetWhitelist`, so this
            # trades its own (redundant, double-login) auth off entirely rather than half-covering
            # it. `ALLOWED_HOSTS`/`ALLOWED_ORIGINS` above are independent of this and still apply.
            MOUSEHOLE_INSECURE_ALLOW_NO_AUTH = "true";
            TZ = config.time.timeZone;
          };

          # `--network=host` makes podman skip creating its own container network namespace and
          # just use whatever namespace the confined systemd unit (`podman-mousehole`, wired up via
          # `vpn-confinement` below) already put its process in - i.e. `proton0`, the same one
          # qBittorrent uses. Mousehole updates MAM with whatever IP its own outbound requests use,
          # so it has to be confined the same way: reachable at MAM only via the VPN tunnel, same
          # egress qBittorrent's own torrent traffic uses (mirrors the project's own docs, which
          # always run Mousehole with `network_mode: "service:<vpn-container>"` alongside the
          # torrent client - see docs/docker-compose-examples/gluetun-qb.md).
          extraOptions = [ "--network=host" ];
          # Pinned to the current "0.5.0" tag's amd64 digest - re-resolve if bumping:
          #   curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:tmmrtn/mousehole:pull" \
          #     | jq -r .token \
          #     | xargs -I{} curl -s -H "Authorization: Bearer {}" \
          #         -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json" \
          #         https://registry-1.docker.io/v2/tmmrtn/mousehole/manifests/<tag> \
          #     | jq -r '.manifests[] | select(.platform.architecture == "amd64") | .digest'
          image = "tmmrtn/mousehole:0.5.0@sha256:a6ce4d1aaa05e82d5fa9df3a5887180203478239f26dfc8a704adf05ec3be805";
          volumes = [ "/metalminds/mousehole:/var/lib/mousehole" ];
        };

        # Opens the `proton0` namespace's own firewall (default INPUT DROP - see
        # qbittorrent-portforward's comment in qbittorrent.nix) for this port, the same way
        # qbittorrent.nix does for its own WebUI port.
        vpnNamespaces.proton0.portMappings = [
          {
            from = port;
            to = port;
          }
        ];
      };

      # No `homepage` block: deliberately not a dashboard tile (it's a set-once-and-forget cookie
      # manager, not something to check daily), but `label`/`icon`/`group` still feed its Authentik
      # application (see virtual-host.nix).
      virtual-host = {
        inherit port;
        group = "Arr Stack";
        host = host.name;
        icon = "https://raw.githubusercontent.com/t-mart/mousehole/master/docs/images/logo/logo.svg";
        label = "Mousehole";
        name = "mousehole";
        protected = true;
        upstreamHost = namespaceAddress;
      };

      vpn-confinement = "podman-mousehole";
    };
}
