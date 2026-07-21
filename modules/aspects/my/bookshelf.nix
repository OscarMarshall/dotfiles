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
          # Bookshelf only reaches this vhost via nginx over loopback (its port isn't opened in
          # the firewall), so every request it sees is "local" -- this drops Bookshelf's own login
          # screen (it's a Readarr fork and shares Readarr's `<APPNAME>__AUTH__REQUIRED` setting)
          # in favor of the Authentik forward-auth gate in front of it, rather than stacking both.
          environment.READARR__AUTH__REQUIRED = "DisabledForLocalAddresses";
          # Pinned to the current "hardcover" tag's digest (Hardcover-sourced metadata, higher
          # quality than the Goodreads-compatible "softcover" variant) -- re-resolve if bumping:
          #   curl -sH "Authorization: Bearer $(curl -s 'https://ghcr.io/token?scope=repository:pennydreadful/bookshelf:pull' | jq -r .token)" \
          #     -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -D - -o /dev/null \
          #     https://ghcr.io/v2/pennydreadful/bookshelf/manifests/hardcover
          image = "ghcr.io/pennydreadful/bookshelf@sha256:388eecc94362580eae31ee0a454be6af516f8a311f8432a521c202fb475f4359";

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
