# The `virtual-host` quirk: any service aspect contributes one alongside its `nixos` config to get
# a reverse-proxied vhost (nginx.nix), a Homepage dashboard tile (homepage.nix), a Cloudflare DNS
# record (dns.nix), and/or a native OIDC application in Authentik (authentik.nix) - declared once,
# consumed by all four. Lives in its own file since it no longer belongs to any single consumer.
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
#   homepage            - (optional) `{ group; label; description; icon ? ...; widget ? {...}; }` -
#                         contributes a Homepage dashboard tile. `icon` (optional) is a Homepage
#                         icon reference (e.g. `"sonarr.png"` from the dashboard-icons library,
#                         `"mdi-<name>"`, `"si-<name>"` - see
#                         https://gethomepage.dev/configs/services/#icons). `widget.api-key`
#                         (optional, bool) marks the widget as needing an API key - homepage.nix
#                         finds the matching secret by scanning for `settings.homepage = "<this
#                         name>";` on that same aspect's `secrets` field
#                         (modules/aspects/my/homepage.nix), rather than this record naming the
#                         secret directly.
#   oidc                - (optional) `{ redirect-paths; client-secret; }` - requests a native
#                         OAuth2/OIDC Provider + Application from Authentik, for a service that
#                         handles its own OIDC login rather than sitting behind Authentik's
#                         forward-auth (`protected` above - a different mechanism, mutually
#                         exclusive with this one in practice). `redirect-paths` is a list of
#                         PATH-ONLY callback routes (e.g. `[ "/login" ]`, whatever the service's own
#                         OIDC docs say to register) - authentik.nix registers one full redirect URI
#                         per path, per hostname this record is actually reachable at (its derived/
#                         overridden `url`, plus the canonical `<name>.<domain>` too if `global`) -
#                         so a globally-exposed service doesn't break OIDC login for people using
#                         the canonical URL. `client-secret` names an age secret (declared on that
#                         same aspect's `secrets` field, with `settings.terraform = "variable";` -
#                         see modules/terranix.nix's header comment) holding the OIDC client secret
#                         value the service itself was already configured to send.
{
  den.quirks.virtual-host.description = "Reverse-proxied virtual hosts served by nginx, optionally exposed globally and/or on the Homepage dashboard";
}
