# The `port-forward` quirk: any aspect contributes one (or a list) alongside its `nixos` config to
# request an inbound port-forwarding rule on the host's Meraki MX (modules/aspects/my/meraki.nix).
# Lives in its own file for the same reason virtual-host.nix does - it no longer belongs to any
# single consumer.
#
# Record shape (a plain attrset, or list of attrsets, under `port-forward = ...;` - never a
# function; see modules/terranix.nix for why that matters for any aspect consuming it as a class
# field). Den auto-flattens list-valued quirk contributions, so an aspect requesting more than one
# port (e.g. a service with multiple worlds) just returns a list.
#
#   name                 - (required) short identifier, used as the Meraki rule's `name`.
#   port                 - (required) the port to forward - same on both the public (WAN) and local
#                          (LAN) side, matching every rule currently configured on harmony's router.
#   protocol             - (optional, default "tcp") "tcp" or "udp".
#   restrict-to-cloudflare - (optional, bool) only allow inbound connections from Cloudflare's
#                          published IP ranges (modules/aspects/my/meraki.nix), instead of from
#                          anywhere. Only meaningful for a port whose traffic actually flows
#                          through Cloudflare's proxy (i.e. its DNS record has `proxied = true;` -
#                          see modules/aspects/my/dns.nix) - setting this on a port Cloudflare
#                          doesn't proxy (Minecraft, Plex) would just block every real client.
{
  den.quirks.port-forward.description = "Inbound port-forwarding rules requested on the host's Meraki MX, applied via Terraform";
}
