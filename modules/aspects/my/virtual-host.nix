# The `virtual-host` quirk: any service aspect contributes one alongside its `nixos` config to get
# a reverse-proxied vhost (nginx.nix), a Homepage dashboard tile (homepage.nix), and/or a
# Cloudflare DNS record (dns.nix) - declared once, consumed by all three. Lives in its own file
# since it no longer belongs to any single consumer.
#
# Record shape (every producer is a plain attrset under `virtual-host = {...};`, never a function -
# see modules/terranix.nix for why that matters for any aspect consuming it as a class field):
#
#   name                - (required) short service identifier. The reverse-proxied hostname is
#                         derived as `${name}.${host.name}.<domain>` unless `url` overrides it
#                         (homepage.nix's own root-domain vhost is the one legitimate exception).
#   host                - (required) `host.name` of the contributing entity. Stamped on every
#                         record so a future multi-host setup can filter/aggregate correctly;
#                         nginx.nix doesn't currently filter on it (quirks are already scoped
#                         per-entity by den), but it's there so that mechanism keeps working if
#                         that scoping assumption ever needs a defensive check again.
#   port                - (optional) upstream port nginx proxy_passes to. Omit for backends that
#                         aren't a plain HTTP proxy_pass target (e.g. Nextcloud's PHP-FPM,
#                         Authentik's own nginx integration, which supply their own `locations`).
#   websockets          - (optional, bool) proxy WebSocket upgrades.
#   protected           - (optional, bool) gate behind Authentik forward-auth.
#   preserveCookieFlags - (optional, bool) skip nginx's blanket cookie-security rewrite, for
#                         backends that set their own correct Set-Cookie flags.
#   global              - (optional, bool) also serve at the bare `<name>.<domain>` alias (an
#                         nginx `serverAlias`) and generate a `cloudflare_dns_record` for it.
#   url                 - (optional) explicit override for the derived hostname.
#   homepage            - (optional) `{ group; label; description; widget ? {...}; }` - contributes
#                         a Homepage dashboard tile. `widget.apiKeySecret` (optional) names an age
#                         secret to surface as a `{{HOMEPAGE_VAR_*}}` template value.
{
  den.quirks.virtual-host.description = "Reverse-proxied virtual hosts served by nginx, optionally exposed globally and/or on the Homepage dashboard";
}
