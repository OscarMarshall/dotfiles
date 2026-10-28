# Client side of my.headscale: joins this host to the self-hosted tailnet, so it's reachable from
# anywhere (no port-forward, unlike a plain WireGuard peer would need) with no manual "turn the VPN
# on" step.
#
# Joining is a one-time, human step per install, through Authentik (headscale.nix's `oidc`):
#   sudo tailscale up --login-server=https://headscale.harmony.silverlight-nex.us --accept-dns
# prints a URL; signing in there registers the node to that Authentik user. tailscaled then
# persists its login in /var/lib/tailscale and reconnects on its own every boot.
#
# harmony doesn't need that: it hosts headscale, so headscale.nix's headscale-self-join mints a
# throwaway key and joins it automatically.
{
  my.tailscale = {
    nixos.services.tailscale.enable = true;
    # The node's identity (machine/node keys) and login live here. Without it an ephemeral-root
    # host (tensoon) would drop out of the tailnet on every boot and need logging in again, coming
    # back as a brand-new node with a fresh tailnet IP and leaving a stale entry in
    # `headscale nodes list`. Inert on hosts without my.preservation (see preserve.nix).
    preserve.directories = [ "/var/lib/tailscale" ];
  };
}
