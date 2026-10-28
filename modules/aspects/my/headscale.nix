# Self-hosted Tailscale coordination server (control plane only - NAT traversal still leans on
# Tailscale's own public DERP relays, see `derp.urls` below, so this isn't a fully third-party-free
# setup, just one where harmony's own network never depends on someone else's control plane). Lets
# my.tailscale clients (melaan/tensoon, and harmony itself) reach each other from
# anywhere without exposing sshd - or anything else - to WAN; see remote-builder.nix's own header.
#
# One-time bootstrap after the first `nixos-rebuild switch` that deploys this (headscale needs to
# actually be running before any of this works):
#   ssh harmony
#   sudo headscale users create oscar
#   sudo headscale users list   # `--user` below takes this numeric ID, not the name
#   sudo headscale preauthkeys create --user <ID> --reusable --expiration 87600h
# Save the printed key in Proton Pass (Personal vault, item "Headscale preauth key", Password
# field), then run `tailscale-join` on each host, harmony included - see my.tailscale's own header.
{
  my.headscale =
    { host, ... }:
    let
      inherit (host) domain;
      url = "headscale.${host.name}.${domain}";
    in
    {
      nixos = {
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
      };
    };
}
