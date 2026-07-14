# Router-as-code for harmony's Meraki MX, managed via terranix (Nix -> Terraform config, see
# modules/terranix.nix) and the Meraki Terraform provider.
#
#   nix run .#harmony-tf.plan   — preview changes
#   nix run .#harmony-tf        — apply
#   nix run .#harmony-tf.destroy
#   nix develop .#harmony-tf    — shell with opentofu
#   nix build .#harmony-tf.config — inspect the generated config.tf.json
#
# The Meraki Dashboard API key is never written into the generated config or into Terraform state -
# the provider reads it from the MERAKI_DASHBOARD_API_KEY env var, produced by the generator below.
# Run `agenix edit secrets/meraki-api-key.age` once to create it, then
# `agenix generate -a && agenix rekey -a`, then decrypt it into your shell before running any of
# the above (alongside the Cloudflare token - see dns.nix):
#
#   set -a; source <(agenix -d secrets/generated/meraki-api.env.age); set +a
#
# One-time setup on Meraki's side: generate a Dashboard API key (Organization > Settings > Dashboard
# API access), and find harmony's network ID (Network-wide > Settings, or via the Dashboard API),
# set as `host.meraki-network-id` (see modules/den.nix; not a secret, just an account-specific
# identifier, so it's ordinary version-controlled Nix rather than a TF_VAR to set by hand).
#
# UNLIKE Cloudflare's `cloudflare_dns_record` (one resource per record - see dns.nix),
# `meraki_networks_appliance_firewall_port_forwarding_rules` represents a network's ENTIRE
# port-forwarding rule list in a single resource/API call - the same "replaces everything" shape as
# Namecheap's `setHosts`, which DNS deliberately avoids. Every rule the router should keep MUST be
# requested via the `port-forward` quirk (modules/aspects/my/port-forward.nix) - anything not
# declared there is removed on the next apply.
#
# `uplink` is hardcoded to "both" (every WAN interface) below - correct for a single-WAN setup;
# revisit if harmony's MX ever gets a second WAN uplink that some rules should exclude.
#
# Cloudflare's published edge IP ranges (https://www.cloudflare.com/ips-v4,
# https://www.cloudflare.com/ips-v6 - pinned here as of 2026-07-14, not fetched dynamically, so
# revisit this list if Cloudflare ever changes it) - used as `allowed_ips` for any port-forward
# rule with `restrict-to-cloudflare = true;`, so only traffic that's actually gone through
# Cloudflare's proxy can reach that port directly.
let
  cloudflareIps = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];
in
{
  my.meraki = { host, ... }: {
    secrets = { secrets, ... }: {
      meraki-api-key = {
        rekeyFile = ../../../secrets/meraki-api-key.age;
        intermediary = true;
      };
      "meraki-api.env".generator = {
        dependencies = { inherit (secrets) meraki-api-key; };
        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'MERAKI_DASHBOARD_API_KEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.meraki-api-key.file})"
          '';
      };
    };

    terranix =
      { port-forward, lib, ... }:
      lib.optionalAttrs (host ? lan-ip) {
        terraform.required_providers.meraki = {
          source = "cisco-open/meraki";
          version = "1.2.4-beta";
        };

        # Credentials aren't set here - the provider reads meraki_dashboard_api_key from
        # MERAKI_DASHBOARD_API_KEY, so nothing sensitive lands in this config or in Terraform
        # state.
        provider.meraki = { };

        resource.meraki_networks_appliance_firewall_port_forwarding_rules.${host.name} = {
          network_id = host.meraki-network-id;
          rules = map (pf: {
            name = pf.name;
            protocol = pf.protocol or "tcp";
            public_port = toString pf.port;
            local_port = toString pf.port;
            lan_ip = host.lan-ip;
            uplink = "both";
            allowed_ips = if pf.restrict-to-cloudflare or false then cloudflareIps else [ "any" ];
          }) port-forward;
        };
      };
  };
}
