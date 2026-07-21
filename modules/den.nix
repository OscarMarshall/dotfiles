{ den, ... }: {
  den = {
    homes.x86_64-linux."omarshal@dev203.meraki.com" = {
      aspect = den.aspects.oscar;
      work = true;
    };

    hosts = {
      aarch64-darwin.OMARSHAL-M-T2QF = {
        graphical = true;
        users.oscar = { };
        work = true;
      };

      x86_64-linux = {
        harmony = {
          # Cloudflare zone ID for silverlight-nex.us (zone's Overview page in the dashboard) - not
          # a secret, just an account-specific resource identifier, so it lives here as ordinary
          # version-controlled Nix rather than a `TF_VAR_cloudflare_zone_id` to set by hand.
          cloudflare-zone-id = "a4f841b1f4d00f1e36e129bae37f70d3";

          # DNS-as-code (modules/aspects/my/dns.nix) reads this for every DNS record this host
          # produces - its `*.harmony.silverlight-nex.us` wildcard and every canonicalized service's
          # global alias alike. Points at the router's dynamic-DNS hostname rather than a static IP,
          # so there's no TF_VAR_harmony_ipv4 to keep up to date by hand.
          dns-record = {
            content = "home-dcgmhnhtnd.dynamic-m.com";
            type = "CNAME";
          };

          # Router-as-code (modules/aspects/my/meraki.nix) reads this to target every inbound
          # port-forwarding rule this host requests (via the `port-forward` quirk) at harmony itself
          # on the Meraki MX's LAN. A static/DHCP-reserved address on the Meraki network.
          lan-ip = "10.10.10.16";
          # Meraki network ID for harmony's network ("Scadrial" - Network-wide > Settings, or the
          # Dashboard API). Same reasoning as `cloudflare-zone-id` above - not a secret.
          meraki-network-id = "L_585467951558176291";
          users.oscar = { };
        };

        melaan = {
          graphical = true;

          users = {
            adelline = { };
            oscar = { };
          };
        };
      };
    };
  };
}
