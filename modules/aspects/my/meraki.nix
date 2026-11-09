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
# the provider reads it from the MERAKI_DASHBOARD_API_KEY env var, contributed below via
# `settings.terraform = true;` (modules/terranix.nix) and collected, alongside the Cloudflare token
# (see dns.nix), into harmony's single `secrets/generated/harmony-tf.env.age`. Run `agenix edit
# secrets/meraki-dashboard-api-key.age` once to create it, then `agenix generate -a && agenix
# rekey -a` to materialize it (from any machine with the YubiKey, same as any other secret).
#
# The `nix run .#harmony-tf*` commands above, by contrast, only work when run ON harmony itself
# (never off-host, e.g. a dev laptop) - they read the already-decrypted
# `/run/agenix/harmony-tf.env` rather than the raw secret file, and harmony's own ZFS dataset
# backs Terraform state too (see modules/terranix.nix's own comments on both).
# `harmony-tf-apply.service` also runs `plan`/`apply` automatically on every `nixos-rebuild
# switch` that changes anything Terraform-relevant, so applying by hand is normally unnecessary.
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
{
  my.meraki = { host, ... }: {
    secrets.meraki-dashboard-api-key = {
      intermediary = true;
      rekeyFile = ../../../secrets/meraki-dashboard-api-key.age;
      settings.terraform = true;
    };

    terranix =
      { lib, port-forward, ... }:
      lib.optionalAttrs (host ? lan-ip) {
        # Credentials aren't set here - the provider reads meraki_dashboard_api_key from
        # MERAKI_DASHBOARD_API_KEY, so nothing sensitive lands in this config or in Terraform
        # state.
        provider.meraki = { };

        resource.meraki_networks_appliance_firewall_port_forwarding_rules.${host.name} = {
          network_id = host.meraki-network-id;

          rules = map (pf: {
            inherit (pf) name;
            allowed_ips = [ "any" ];
            lan_ip = host.lan-ip;
            local_port = toString pf.port;
            protocol = pf.protocol or "tcp";
            public_port = toString pf.port;
            uplink = "both";
          }) port-forward;
        };

        terraform.required_providers.meraki = {
          source = "cisco-open/meraki";
          # Every release cisco-open/meraki has ever published is a pre-release (alpha/beta - see
          # https://registry.terraform.io/v1/providers/cisco-open/meraki/versions, no stable line
          # exists) - `tofu init` excludes pre-releases from resolution entirely unless the
          # constraint itself references one, so unlike every OTHER provider here, this one can't
          # go unconstrained: with no version at all, `tofu init` fails outright ("no available
          # releases match the given constraints"). An exact pin is the only thing that actually
          # works, confirmed live - a `>=` floor referencing this SAME version still fails with the
          # identical error (OpenTofu's prerelease matching apparently requires an exact match, not
          # just any constraint that mentions one). So unlike the rest, this one really is pinned in
          # the traditional sense - bump this by hand (checking that registry link above for
          # whatever's newest) whenever a newer prerelease is wanted; `tofu init -upgrade` alone
          # can't move it.
          version = "1.2.4-beta";
        };
      };
  };
}
