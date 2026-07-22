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
#   basicAuthSecret     - (optional) names an age secret holding an htpasswd-format (APR1-MD5)
#                         credentials file - gates the vhost on HTTP Basic Auth instead of
#                         Authentik, for backends called by scripts/machines rather than browsers
#                         (no session to carry a forward-auth cookie). Mutually exclusive with
#                         `protected` in practice, like `oidc` above.
#   preserveCookieFlags - (optional, bool) skip nginx's blanket cookie-security rewrite, for
#                         backends that set their own correct Set-Cookie flags.
#   global              - (optional, bool) also serve at the bare `<name>.<domain>` alias (an
#                         nginx `serverAlias`) and generate a `cloudflare_dns_record` for it.
#   url                 - (optional) explicit override for the derived hostname.
#   label               - (optional) human-readable display name, defaulting to `name`. Used for
#                         BOTH the Homepage tile's title and the Authentik application's name, so
#                         a service is called the same thing everywhere it's presented to a person.
#                         Only needed where `name` (a lowercase URL component) isn't the brand's own
#                         styling - e.g. `name = "qbittorrent"` but `label = "qBittorrent"`.
#   icon                - (optional) service icon, used for BOTH the Homepage tile and the Authentik
#                         application (see `label`). Either a Homepage icon reference - a
#                         dashboard-icons filename (`"sonarr.svg"`) or `"mdi-<name>"`, see
#                         https://gethomepage.dev/configs/services/#icons - or an absolute URL, for
#                         apps whose only real logo lives in their own upstream repo. Prefer SVG.
#                         authentik.nix translates the shorthands into plain URLs for `meta_icon`.
#   group               - (optional) which section this service is filed under, for BOTH the Homepage
#                         dashboard and Authentik's application library (see `label`). Required in
#                         practice for anything with a `homepage` block below, since a tile has to
#                         land in some section.
#   homepage            - (optional) `{ description; widget ? {...}; }` - contributes a Homepage
#                         dashboard tile (`label`/`icon`/`group` above feed it too, but live at the
#                         top level since Authentik wants the same three). Omit for a service that
#                         shouldn't appear on the dashboard at all but may still be an Authentik
#                         application (e.g. qbittorrent). `widget.api-key` (optional, bool) marks the
#                         widget as needing an API key - homepage.nix finds the matching secret by
#                         scanning for `settings.homepage = "<this name>";` on that same aspect's
#                         `secrets` field (modules/aspects/my/homepage.nix), rather than this record
#                         naming the secret directly.
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
