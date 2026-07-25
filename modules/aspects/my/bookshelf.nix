let
  # Den has the same singleton constraint here as when this was a native build: two `includes`
  # entries for the *same* named aspect are treated as one aspect identity and merged
  # last-write-wins, not as two separate instances (see `den.lib.aspects.fx.identity`, which keys
  # resolved nodes by aspect name). So instead of parameterizing one `my.bookshelf` aspect, this
  # defines one genuinely-distinct named aspect per instance (`my.bookshelf-ebooks`,
  # `my.bookshelf-audiobooks`), sharing this builder.
  mkBookshelfInstance =
    {
      description,
      instance,
      label,
      port,
    }:
    {
      global ? false,
    }:
    { host, ... }:
    let
      name = "bookshelf-${instance}";
    in
    {
      dataset = {
        inherit name;
        pool = "metalminds";
      };

      nixos = {
        virtualisation.oci-containers.containers.${name} = {
          environment = {
            # Bookshelf only reaches this vhost via nginx (its port isn't opened in the firewall),
            # and every such request already passed the Authentik forward-auth gate in front of it -
            # so Bookshelf's own login is pure redundancy. `READARR__AUTH__REQUIRED =
            # "DisabledForLocalAddresses"` used to paper over that by treating loopback-proxied
            # requests as local, but ASP.NET Core's forwarded-headers middleware (Bookshelf is a
            # Readarr fork and shares its auth code) rewrites the remote address from nginx's
            # X-Forwarded-For header before that check runs, so "local" actually tracked the real
            # client's address - true from the LAN, false the moment access came from anywhere else,
            # which is why the login started reappearing. `READARR__AUTH__METHOD = "External"`
            # (unlisted in Readarr/Bookshelf's own UI, but a real, supported value) sidesteps the IP
            # heuristic entirely: it treats every request as already authenticated, full stop,
            # leaving Authentik as the sole real gate - matching what this was always supposed to do.
            # `READARR__AUTH__REQUIRED` is pinned to "Enabled" alongside it (rather than left unset)
            # so nothing falls back to Bookshelf's own persisted config.xml value, which could still
            # be the old "DisabledForLocalAddresses" - it's moot once `METHOD` already authenticates
            # every request, but keeps that heuristic from silently reappearing if it ever weren't.
            READARR__AUTH__METHOD = "External";
            READARR__AUTH__REQUIRED = "Enabled";
          };

          # Pinned to the current "hardcover" tag's digest (Hardcover-sourced metadata, higher
          # quality than the Goodreads-compatible "softcover" variant) -- re-resolve if bumping:
          #   curl -sH "Authorization: Bearer $(curl -s 'https://ghcr.io/token?scope=repository:pennydreadful/bookshelf:pull' | jq -r .token)" \
          #     -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -D - -o /dev/null \
          #     https://ghcr.io/v2/pennydreadful/bookshelf/manifests/hardcover
          image = "ghcr.io/pennydreadful/bookshelf:hardcover@sha256:388eecc94362580eae31ee0a454be6af516f8a311f8432a521c202fb475f4359";

          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];

          volumes = [ "/metalminds/${name}:/config" ];
        };
      };

      virtual-host = {
        inherit global name port;
        group = "Arr Stack";
        homepage = { inherit description; };
        host = host.name;
        # No dashboard-icons entry for pennydreadful/bookshelf specifically (its "audiobookshelf"
        # entry is a different, unrelated app) - its own upstream logo instead. Named Readarr.svg
        # upstream since Bookshelf is a Readarr fork.
        icon = "https://raw.githubusercontent.com/pennydreadful/bookshelf/develop/Logo/Readarr.svg";
        label = "Bookshelf (${label})";
        protected = true;
      };
    };
in
{
  my = {
    bookshelf-audiobooks = mkBookshelfInstance {
      description = "Audiobook manager";
      instance = "audiobooks";
      label = "Audiobooks";
      port = 8788;
    };

    bookshelf-ebooks = mkBookshelfInstance {
      description = "Ebook manager";
      instance = "ebooks";
      label = "Ebooks";
      port = 8787;
    };
  };
}
