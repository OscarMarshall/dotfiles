# Mailgun-as-code, managed via terranix (Nix -> Terraform config, see modules/terranix.nix) and the
# `wgebis/mailgun` Terraform provider - the actively maintained fork; the original
# `hashicorp/terraform-provider-mailgun` is archived in its favor. Owns only the account-level
# `mailgun_domain` and the Cloudflare DNS records that verify it; NOT per-service mailboxes - both
# authentik.nix and nextcloud.nix send through this same domain but want their own, independently
# rotatable credential, so each of THEM owns its own `mailgun_domain_credential` (secrets, resource,
# and all), cross-referencing `mailgun_domain.default` defined here purely by name - same as any
# other cross-resource reference already in this repo (e.g. authentik.nix's own `authentik_source_oauth`
# references), no Nix-level coupling needed since Den merges every aspect's `terranix` field into one
# combined Terraform config per host.
#
# This domain used to be Proton's (dns.nix's now-removed proton-mx/dkim/dmarc/spf/verification
# records) - dropped entirely, not layered alongside Mailgun, at the user's own call. That means
# this domain no longer RECEIVES mail at all (Mailgun is send-only here, no `wildcard`/receiving
# setup) - deliberate, not an oversight.
#
# One-time setup: sign up for Mailgun, create an API key, `agenix edit secrets/mailgun-api-key.age`
# with just the key, then `agenix generate -a && agenix rekey -a`. After the first
# `nix run .#harmony-tf`, nudge domain verification (Mailgun also polls for it on its own
# eventually, just slower):
#
#   curl -s -X PUT -u "api:$MAILGUN_API_KEY" "https://api.mailgun.net/v4/domains/<domain>/verify"
{
  my.mailgun = { host, ... }: {
    secrets.mailgun-api-key = {
      intermediary = true;
      rekeyFile = ../../../secrets/mailgun-api-key.age;
      settings.terraform = true;
    };

    terranix = _: {
      # Credentials aren't set here - the provider reads api_key from MAILGUN_API_KEY, so nothing
      # sensitive lands in this config or in Terraform state.
      provider.mailgun = { };

      resource = {
        # Mirrors the Cloudflare provider's own example for this resource: `sending_records_set`
        # is a Terraform-computed SET OF OBJECTS (Mailgun only returns the actual DKIM/SPF values
        # once the domain exists) - unlike every static `cloudflare_dns_record` in dns.nix, Nix
        # can't enumerate these at eval time, only at apply time, so this has to be a REAL
        # Terraform `for_each`. That can't be the raw set itself, though - `for_each` only accepts
        # a map or a set of STRINGS, never a set of objects, so the `for` expression below converts
        # it into a map keyed by each record's own `id` (confirmed via `tofu providers schema
        # -json` that `id` exists on these objects, alongside `name`/`record_type`/`value`).
        #
        # Still requires a TWO-STEP apply the first time, and there's no config-side fix for that:
        # `for_each`'s keys have to be known at plan time, and here they're literally the `id`s
        # Mailgun assigns when it creates the domain, which doesn't exist yet on a from-scratch
        # apply. First apply will error on just this resource (`-exclude
        # cloudflare_dns_record.mailgun-sending`, or let it fail alongside everything else
        # succeeding); once `mailgun_domain.default` is in state, a second apply converges.
        cloudflare_dns_record.mailgun-sending = {
          content = "\${each.value.value}";
          for_each = "\${ { for record in mailgun_domain.default.sending_records_set : record.id => record } }";
          name = "\${each.value.name}";
          proxied = false;
          ttl = 300;
          type = "\${each.value.record_type}";
          zone_id = host.cloudflare-zone-id;
        };

        mailgun_domain.default = {
          name = host.domain;
          # region/spam_action/dkim_key_size left at provider defaults; deliberately NOT
          # `use_automatic_sender_security` - the DNS records below are how we manage
          # verification ourselves, through the same Cloudflare zone every other record in
          # dns.nix goes through.
        };
      };

      terraform.required_providers.mailgun = {
        source = "wgebis/mailgun";
        version = "0.10.0";
      };
    };
  };
}
