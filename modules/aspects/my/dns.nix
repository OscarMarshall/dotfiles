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
    secrets.cloudflare-api-token = {
      intermediary = true;
      rekeyFile = ../../../secrets/cloudflare-api-token.age;
      settings.terraform = true;
    };

    terranix =
      { lib, virtual-host, ... }:
      let
        domain = "silverlight-nex.us";
        globalHosts = lib.filter (vh: vh.global or false) virtual-host;
      in
      lib.optionalAttrs (host ? dns-record) {
        # Credentials aren't set here - the provider reads api_token from CLOUDFLARE_API_TOKEN, so
        # nothing sensitive lands in this config or in Terraform state.
        provider.cloudflare = { };

        # Unlike Namecheap's setHosts (which replaces the entire zone in one call), each record
        # here is its own independent resource - Terraform only ever touches what's declared
        # below, so there's no OVERWRITE-style footgun for the rest of the zone.
        resource.cloudflare_dns_record =
          lib.listToAttrs (
            map (vh: {
              inherit (vh) name;

              value = {
                inherit (host.dns-record) content type;
                name = "${vh.name}.${domain}";
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
                ttl = 1800;
                zone_id = host.cloudflare-zone-id;
              };
            }) globalHosts
          )
          // {
            # The host's own root/apex hostname - NOT covered by the wildcard above (a wildcard
            # only matches names with something before it, never its own apex), and homepage.nix's
            # `url = "${host.name}.${domain}"` deliberately doesn't go through the `global`/
            # `globalHosts` path above either (that would produce `homepage.${domain}`, not this).
            "${host.name}-root" = {
              inherit (host.dns-record) content type;
              name = "${host.name}.${domain}";
              proxied = false;
              ttl = 1800;
              zone_id = host.cloudflare-zone-id;
            };

            "${host.name}-wildcard" = {
              inherit (host.dns-record) content type;
              name = "*.${host.name}.${domain}";
              proxied = false;
              ttl = 1800;
              zone_id = host.cloudflare-zone-id;
            };

            # DKIM signing keys - lets recipients verify mail Proton sends on ${domain}'s behalf
            # actually came from Proton. Three, matching Proton's own custom-domain setup (it
            # rotates through them), all pointing at the same per-account target Proton generated.
            proton-dkim-1 = {
              content = "protonmail.domainkey.de6twmuoanri7twyqgfpqae6nzexlkrk2374nj7blkbxfxlmtyjqq.domains.proton.ch";
              name = "protonmail._domainkey.${domain}";
              proxied = false;
              ttl = 1800;
              type = "CNAME";
              zone_id = host.cloudflare-zone-id;
            };

            proton-dkim-2 = {
              content = "protonmail2.domainkey.de6twmuoanri7twyqgfpqae6nzexlkrk2374nj7blkbxfxlmtyjqq.domains.proton.ch";
              name = "protonmail2._domainkey.${domain}";
              proxied = false;
              ttl = 1800;
              type = "CNAME";
              zone_id = host.cloudflare-zone-id;
            };

            proton-dkim-3 = {
              content = "protonmail3.domainkey.de6twmuoanri7twyqgfpqae6nzexlkrk2374nj7blkbxfxlmtyjqq.domains.proton.ch";
              name = "protonmail3._domainkey.${domain}";
              proxied = false;
              ttl = 1800;
              type = "CNAME";
              zone_id = host.cloudflare-zone-id;
            };

            # `p=quarantine` (not `p=reject`) - recipients failing SPF/DKIM land in spam rather than
            # being dropped outright, since this is a first DMARC policy for the domain and there's
            # no reporting address configured yet to catch legitimate mail this misclassifies.
            proton-dmarc = {
              content = "v=DMARC1; p=quarantine";
              name = "_dmarc.${domain}";
              proxied = false;
              ttl = 1800;
              type = "TXT";
              zone_id = host.cloudflare-zone-id;
            };

            # Lets Proton actually receive mail for ${domain} (nextcloud.nix's Postfix relay only
            # covers sending) - two MX records, not one, since Proton's own setup instructions call
            # for both a primary and a secondary (lower-priority) mail exchanger.
            proton-mx-primary = {
              content = "mail.protonmail.ch";
              name = domain;
              priority = 10;
              proxied = false;
              ttl = 1800;
              type = "MX";
              zone_id = host.cloudflare-zone-id;
            };

            proton-mx-secondary = {
              content = "mailsec.protonmail.ch";
              name = domain;
              priority = 20;
              proxied = false;
              ttl = 1800;
              type = "MX";
              zone_id = host.cloudflare-zone-id;
            };

            # Authorizes Proton's servers as legitimate senders for ${domain} - without this,
            # recipients' own SPF checks fail every message nextcloud.nix's Postfix relay sends.
            proton-spf = {
              content = "v=spf1 include:_spf.protonmail.ch ~all";
              name = domain;
              proxied = false;
              ttl = 1800;
              type = "TXT";
              zone_id = host.cloudflare-zone-id;
            };

            # Proves domain ownership to Proton so nextcloud@${domain} can be verified as a custom
            # domain address there (nextcloud.nix's Postfix relay uses it). Lives at the zone apex,
            # unrelated to any single service, so it doesn't fit the per-host/per-service loops
            # above - a one-off record with nothing to derive it from. TXT can't be proxied
            # regardless of the flag.
            proton-verification = {
              content = "protonmail-verification=c79b190a4d3afe77f16020917ec9e11f1fc5ea4c";
              name = domain;
              proxied = false;
              ttl = 1800;
              type = "TXT";
              zone_id = host.cloudflare-zone-id;
            };
          };

        terraform.required_providers.cloudflare = {
          source = "cloudflare/cloudflare";
          version = "~> 5";
        };
      };
  };

  perSystem =
    { lib, pkgs, ... }:
    let
      allEntries = lib.concatLists (
        lib.mapAttrsToList (host: hostnames: map (hostname: { inherit host hostname; }) hostnames) hostnamesByHost
      );
      # Group by hostname; anything claimed by more than one DISTINCT host is a collision.
      collisions = lib.filterAttrs (_: entries: lib.length (lib.unique (map (e: e.host) entries)) > 1) (
        lib.groupBy (e: e.hostname) allEntries
      );
      # host -> every hostname its nginx vhosts actually claim: both `serverAliases` AND each
      # vhost's own PRIMARY name (the attribute key). The primary name matters too, not just
      # aliases: a service's `url` override can already equal the canonical global name (e.g.
      # authentik.nix/storyteller.nix when `global = true;`), and nginx.nix then deliberately
      # skips adding a redundant alias for it (see its own comment) - so that hostname would
      # otherwise never appear in `serverAliases` at all and slip past this check entirely.
      # Including every host-scoped primary name too (`${vh.name}.${host.name}.${domain}`) is
      # harmless: `host.name` differs per host by construction, so those can never collide across
      # hosts and only the genuinely global-scoped names below ever populate `collisions`.
      hostnamesByHost = lib.mapAttrs (
        _: hostCfg:
        lib.concatLists (
          lib.mapAttrsToList (name: vh: [ name ] ++ (vh.serverAliases or [ ])) (hostCfg.config.services.nginx.virtualHosts or { })
        )
      ) config.flake.nixosConfigurations;
    in
    {
      checks.dns-global-uniqueness =
        if collisions == { } then
          pkgs.runCommand "dns-global-uniqueness-check" { } "touch $out"
        else
          throw ''
            Two or more hosts serve the same public hostname - most likely two DIFFERENT hosts
            both flag `global = true;` on a same-named service, which would create competing
            Cloudflare DNS records for it:
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                hostname: entries: "  ${hostname}: ${lib.concatStringsSep ", " (lib.unique (map (e: e.host) entries))}"
              ) collisions
            )}
            Rename one of the services, or drop `global` from all but one host.
          '';
    };
}
