# Self-hosted Tailscale coordination server (control plane only - NAT traversal still leans on
# Tailscale's own public DERP relays, see `derp.urls` below, so this isn't a fully third-party-free
# setup, just one where harmony's own network never depends on someone else's control plane). Lets
# my.tailscale clients (melaan/tensoon, and harmony itself) reach each other from
# anywhere without exposing sshd - or anything else - to WAN; see remote-builder.nix's own header.
#
# harmony joins its own tailnet on its own (headscale-self-join below). The laptops need a reusable
# preauth key, minted once after the first `nixos-rebuild switch` that deploys this:
#   ssh harmony
#   sudo headscale users list   # `--user` below takes this numeric ID, not the name
#   sudo headscale preauthkeys create --user <ID> --reusable --expiration 87600h
# Save the printed key in Proton Pass (Personal vault, Custom item "Headscale preauth key", hidden
# "API Key" field), then run `tailscale-join` once on each laptop - see my.tailscale's own header.
{
  my.headscale =
    { host, ... }:
    let
      inherit (host) domain;
      url = "headscale.${host.name}.${domain}";
    in
    {
      nixos = { config, pkgs, ... }: {
        # harmony's own my.tailscale node (harmony.nix) talks to this same server_url, which is a
        # DNS-only record pointing at the router's dynamic-DNS WAN hostname (dns.nix). Most
        # consumer routers - the Meraki MX included - don't do NAT hairpin/loopback for their own
        # forwarded ports, so a request to that hostname from harmony's own LAN interface would
        # time out or bounce off the router instead of coming back to itself. Force it to loopback.
        networking.extraHosts = "127.0.0.1 ${url}";

        services.headscale = {
          enable = true;
          port = 8080;

          settings = {
            derp = {
              # Not self-hosting a DERP relay - `urls` (Tailscale's own public map) is enough to get
              # NAT traversal without running yet another service.
              server.enabled = false;
              urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
            };

            dns = {
              # MUST differ from server_url's domain (headscale refuses to start otherwise) - this
              # namespace is only ever resolved by tailnet members via MagicDNS, never published to
              # public DNS, so it doesn't need to be a real delegated subdomain.
              base_domain = "ts.${domain}";
              magic_dns = true;

              # Required by the module regardless of `override_local_dns` (left at its false
              # default - clients keep their own resolver for everything outside base_domain, this
              # is only the fallback used for the tailnet's OWN forward/reverse lookups).
              nameservers.global = [
                "1.1.1.1"
                "1.0.0.1"
              ];
            };

            server_url = "https://${url}";
          };
        };

        # harmony is the one tailnet member that can mint its own preauth key, so it joins itself
        # instead of needing `tailscale-join` and the Proton Pass key (pass-cli can't unlock over a
        # headless SSH session anyway). The key is single-use and expires in 5 minutes, so nothing
        # long-lived is left behind. A no-op on every boot after the first - /var/lib/tailscale is
        # persistent, so tailscaled comes back up already logged in - and also whenever tailscaled is
        # in any state other than NeedsLogin (e.g. a deliberate `tailscale down`), so it never fights
        # a manual change. Goes through nginx at the public URL (looped back by extraHosts above) so
        # harmony's control URL matches server_url like every other node's.
        systemd.services.headscale-self-join = {
          wantedBy = [ "multi-user.target" ];

          after = [
            "headscale.service"
            "network-online.target"
            "nginx.service"
            "tailscaled.service"
          ];

          path = [
            config.services.headscale.package
            config.services.tailscale.package
            pkgs.jq
          ];

          requires = [ "headscale.service" ];

          script = ''
            # tailscaled reports NoState (or nothing) until it has finished loading its state.
            state=
            for _ in $(seq 30); do
              state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty') || true
              if [ -n "$state" ] && [ "$state" != NoState ]; then break; fi
              sleep 1
            done
            if [ "$state" != NeedsLogin ]; then exit 0; fi

            # headscale's CLI socket appears a moment after the unit is marked started.
            for _ in $(seq 30); do
              if headscale users list >/dev/null 2>&1; then break; fi
              sleep 1
            done

            id=$(headscale users list --name oscar -o json | jq -r '.[0].id // empty')
            if [ -z "$id" ]; then id=$(headscale users create oscar -o json | jq -r .id); fi

            key=$(mktemp)
            trap 'rm -f "$key"' EXIT
            headscale preauthkeys create --user "$id" --expiration 5m -o json | jq -j .key > "$key"
            # `tailscale up` otherwise retries a failing registration forever, which would leave this
            # oneshot "activating" and a `nixos-rebuild switch` waiting on it. The key outlives this,
            # so a timed-out attempt fails visibly and the next boot (or a restart) mints a new one.
            tailscale up --accept-dns --auth-key="file:$key" --login-server=https://${url} --timeout=2m
          '';

          serviceConfig.Type = "oneshot";

          wants = [
            "network-online.target"
            "tailscaled.service"
          ];
        };
      };

      # No `oidc` (unlike Authentik's other native-login apps, e.g. storyteller.nix) - a reusable
      # preauth key is simpler for a small, fixed set of already-known machines and skips having to
      # hand-copy an Authentik-generated client_id into headscale's config as a second manual step.
      virtual-host = {
        group = "Infra";
        homepage.description = "Self-hosted Tailscale coordination server";
        host = host.name;
        icon = "headscale.svg";
        name = "headscale";
        port = 8080;
        # Tailscale clients reach headscale's control protocol (ts2021) by sending an HTTP
        # `Upgrade: tailscale-control-protocol` request, the same mechanism as a WebSocket upgrade.
        # Without it nginx strips `Connection`/`Upgrade` (see nginx.nix's `proxyWebsockets` comment),
        # headscale answers 500, and `tailscale up` retries `/machine/register` forever - `/key`
        # still works, so it looks reachable from outside.
        websockets = true;
      };
    };
}
