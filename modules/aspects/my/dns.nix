# DNS-as-code for canonicalized ("global") services, managed via terranix (Nix -> Terraform
# config, see modules/terranix.nix) and the Cloudflare provider. Registration stays at Namecheap -
# only DNS hosting (nameservers) moves to Cloudflare, for its free/no-minimum-spend API access.
#
#   nix run .#harmony-tf.plan   — preview changes
#   nix run .#harmony-tf        — apply
#   nix run .#harmony-tf.destroy
#   nix develop .#harmony-tf    — shell with opentofu
#   nix build .#harmony-tf.config — inspect the generated config.tf.json
#
# The Cloudflare API token is never written into the generated config or into Terraform state -
# the provider reads it from the CLOUDFLARE_API_TOKEN env var, contributed below via
# `settings.terraform = true;` (modules/terranix.nix) and collected into harmony's single
# `secrets/generated/harmony-tf.env.age`, decrypted and sourced automatically by `nix run
# .#harmony-tf*`. Run `agenix generate -a && agenix rekey -a` once to materialize it.
#
# One-time setup on Cloudflare's side: add silverlight-nex.us as a site (free plan), note its Zone
# ID from the zone's Overview page (set as `host.cloudflare-zone-id` - see modules/den.nix; not a
# secret, just an account-specific identifier, so it's ordinary version-controlled Nix rather than
# a TF_VAR to set by hand), create an API token scoped to `Zone / DNS / Edit` for that zone, and
# switch the domain's nameservers at Namecheap to the ones Cloudflare assigns.
#
# Every DNS record for a host - its own root/apex hostname (`<host>.<domain>` - homepage.nix's
# root landing page lives here, deliberately not under the wildcard, see its own comment), its
# wildcard (`*.<host>.<domain>`), and every canonicalized service's global alias (`<name>.<domain>`)
# - points at the same place: `host.dns-record` (see modules/den.nix), a plain `{ type; content; }`.
# One field on the host definition, applying to every record that host produces; a host with no
# `dns-record` gets no DNS resources at all. This also means no `TF_VAR_<host>_ipv4` to keep
# updated by hand - `content` is ordinary version-controlled Nix, typically a CNAME to a router's
# dynamic-DNS hostname.
#
# Which services get a global alias comes from the `virtual-host` quirk (the same aggregated data
# nginx.nix uses for `serverAliases`) - flip `global = true;` on a service's `virtual-host` entry
# and it picks up a DNS record here automatically, nothing else to touch. This only works because
# modules/terranix.nix shims a `warnings` option into terranix's module type - see its header
# comment for why that's needed for a `terranix` field to consume den context (a quirk, here) at
# all.
#
# `host` is requested at the ASPECT level (`my.dns = { host, ... }: {...};`) - that's the only
# place Den resolves entity-kind context. `virtual-host` is a quirk, which Den only delivers at
# the CLASS level, so it's requested on the `terranix` field itself instead
# (`terranix = { virtual-host, ... }: {...};`); requesting it on the outer aspect wrapper alongside
# `host` silently makes the whole aspect (including `secrets`!) inert - Den only recognizes
# host/user/home as aspect-level parametric args, so an unrecognized name there isn't an error, the
# aspect just never gets invoked at all.
#
# `nix flake check` also fails if two DIFFERENT hosts both flag a service `global = true;` under
# the same alias - each host's Terraform config (modules/terranix.nix) is a separate,
# non-interacting apply/state, so nothing else would catch two hosts creating competing Cloudflare
# records for the same hostname. That check reads every host's own resolved
# `services.nginx.virtualHosts` straight out of `config.flake.nixosConfigurations` from `perSystem`
# below - safe ONLY because it references the file's own top-level `config` (closed over, not
# re-requested). Re-requesting `config` in `perSystem`'s own arg list shadows it with a different,
# per-system-scoped `config` that closes a real cycle on `.flake.nixosConfigurations` ("infinite
# recursion encountered") - this bit us once already; don't add `config` to the perSystem function
# signature below.
{ config, ... }: {
  my.dns = { host, ... }: {
    secrets = {
      cloudflare-api-token = {
        rekeyFile = ../../../secrets/cloudflare-api-token.age;
        intermediary = true;
        settings.terraform = true;
      };
    };

    terranix =
      { virtual-host, lib, ... }:
      let
        domain = "silverlight-nex.us";
        globalHosts = lib.filter (vh: vh.global or false) virtual-host;
      in
      lib.optionalAttrs (host ? dns-record) {
        terraform.required_providers.cloudflare = {
          source = "cloudflare/cloudflare";
          version = "~> 5";
        };

        # Credentials aren't set here - the provider reads api_token from CLOUDFLARE_API_TOKEN, so
        # nothing sensitive lands in this config or in Terraform state.
        provider.cloudflare = { };

        # Unlike Namecheap's setHosts (which replaces the entire zone in one call), each record
        # here is its own independent resource - Terraform only ever touches what's declared
        # below, so there's no OVERWRITE-style footgun for the rest of the zone.
        resource.cloudflare_dns_record =
          lib.listToAttrs (
            map (vh: {
              name = vh.name;
              value = {
                zone_id = host.cloudflare-zone-id;
                name = "${vh.name}.${domain}";
                inherit (host.dns-record) type content;
                ttl = 1800;
                # DNS-only (not proxied through Cloudflare's edge). This one-level name is
                # actually covered by Cloudflare's free Universal SSL cert, but the per-host
                # wildcard below (`*.${host.name}.${domain}`) is namespaced two levels deep,
                # which that cert doesn't cover (it only spans the apex and one level of
                # wildcard) - proxying it without Cloudflare's paid Advanced Certificate Manager
                # add-on breaks TLS at the edge before nginx is ever reached. Kept DNS-only here
                # too for consistency, since real client traffic now arrives directly (nginx.nix's
                # port-forward rules no longer restrict to Cloudflare's IPs) and nginx already
                # terminates with its own per-host ACME cert.
                proxied = false;
              };
            }) globalHosts
          )
          // {
            "${host.name}-wildcard" = {
              zone_id = host.cloudflare-zone-id;
              name = "*.${host.name}.${domain}";
              inherit (host.dns-record) type content;
              ttl = 1800;
              proxied = false;
            };

            # The host's own root/apex hostname - NOT covered by the wildcard above (a wildcard
            # only matches names with something before it, never its own apex), and homepage.nix's
            # `url = "${host.name}.${domain}"` deliberately doesn't go through the `global`/
            # `globalHosts` path above either (that would produce `homepage.${domain}`, not this).
            "${host.name}-root" = {
              zone_id = host.cloudflare-zone-id;
              name = "${host.name}.${domain}";
              inherit (host.dns-record) type content;
              ttl = 1800;
              proxied = false;
            };
          };
      };
  };

  perSystem =
    { pkgs, lib, ... }:
    let
      # host -> every alias its nginx vhosts actually claim (empty unless `global = true;` set
      # somewhere), read straight from each host's own resolved NixOS config.
      globalAliasesByHost = lib.mapAttrs (
        _: hostCfg:
        lib.concatMap (vh: vh.serverAliases or [ ]) (lib.attrValues (hostCfg.config.services.nginx.virtualHosts or { }))
      ) config.flake.nixosConfigurations;

      allEntries = lib.concatLists (
        lib.mapAttrsToList (host: aliases: map (alias: { inherit host alias; }) aliases) globalAliasesByHost
      );

      # Group by alias; anything claimed by more than one DISTINCT host is a collision.
      collisions = lib.filterAttrs (_: entries: lib.length (lib.unique (map (e: e.host) entries)) > 1) (
        lib.groupBy (e: e.alias) allEntries
      );
    in
    {
      checks.dns-global-uniqueness =
        if collisions == { } then
          pkgs.runCommand "dns-global-uniqueness-check" { } "touch $out"
        else
          throw ''
            Two or more hosts flag `global = true;` on services that share the same alias, which
            would create competing Cloudflare DNS records for the same hostname:
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                alias: entries: "  ${alias}: ${lib.concatStringsSep ", " (lib.unique (map (e: e.host) entries))}"
              ) collisions
            )}
            Rename one of the services, or drop `global` from all but one host.
          '';
    };
}
