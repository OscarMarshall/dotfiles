{
  my.storyteller =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 8001;

      # Like authentik.nix's own `url` (and unlike every other service's `global`, which merely adds
      # an ALIAS alongside the host-scoped name - see virtual-host.nix), `global` here SWITCHES the
      # served hostname rather than adding to it. Storyteller pins its session cookie's `Domain` to
      # whatever hostname `AUTH_URL` names (see `AUTH_URL` below), and
      # `storyteller.${host.name}.${host.domain}` is NOT a subdomain of `storyteller.${host.domain}` -
      # so a browser on the name AUTH_URL doesn't cover would reject the session cookie and silently
      # loop back to the login page. One name has to be canonical; serving the other would just be a
      # trap.
      url = if global then "storyteller.${host.domain}" else "storyteller.${host.name}.${host.domain}";
    in
    {
      dataset = [
        {
          name = "storyteller";
          pool = "metalminds";
          units = [ "podman-storyteller" ];
        }
        {
          # The shared `/books` library (bookshelf.nix's own `books` dataset entry, which owns
          # this dataset overall - `samba`/`guestAccess` deliberately NOT duplicated here, since
          # those are bookshelf.nix's concern and samba.nix's own consumer filters the raw
          # `dataset` list for `samba = true` entries before its own separate dedup, so leaving
          # them off here doesn't affect the Samba share either way). `user`/`group` ARE repeated
          # here verbatim rather than left unset, because THOSE are what zfs.nix's own
          # `ensureDatasetService` reads when it flattens/dedupes every contributor's entries by
          # `zfs-dataset-<pool>-<name>` name alone (`lib.listToAttrs`, last-entry-wins): an entry
          # missing `user`/`group` here could win that dedup and silently drop the chown Bookshelf
          # relies on. Storyteller reads (and, per its own auto-import docs, writes metadata back
          # into) this library from its own mount below - see the `PUID`/`PGID` comment there for
          # why no further `aclUsers` grant is needed on top of this.
          group = "readarr";
          name = "books";
          pool = "metalminds";
          units = [ "podman-storyteller" ];
          user = "readarr";
        }
      ];

      nixos = { config, ... }: {
        # Storyteller's `PUID`/`PGID` below (and the `books` dataset entry above) assume
        # bookshelf.nix's shared `readarr` user/group is also declared on this host. Without this,
        # `config.users.users.readarr.uid` below would fail evaluation with a bare "attribute
        # 'readarr' missing" - this turns that into an actionable message instead. NixOS resolves
        # `config.assertions` before forcing the rest of `config.system.build.toplevel`, so a
        # failing assertion here pre-empts that crash rather than racing it.
        assertions = [
          {
            assertion = config.users.users ? readarr;
            message = "my.storyteller mounts the shared /library dataset and runs its container as bookshelf.nix's `readarr` user (PUID/PGID) - enable `my.bookshelf` (or otherwise declare a `readarr` user/group) on this host too.";
          }
        ];

        virtualisation.oci-containers.containers.storyteller = {
          environment = {
            # Storyteller's Auth.js base URL: its own origin plus Auth.js's `basePath`. Required for
            # OAuth/OIDC login, and what its session cookie's `Domain` is pinned to - see `url`
            # above for why that forces a single canonical hostname.
            AUTH_URL = "https://${url}/api/v2/auth";
            ENABLE_WEB_READER = "true";
            # Storyteller drops root to a baked-in `storyteller` user (uid/gid 1000) by default,
            # and its entrypoint only ever chowns its OWN `/data` volume to match `PUID`/`PGID` -
            # never any other mounted volume (per its self-hosting docs' own "Permission
            # management" section), so the shared `/library` mount below is only readable/writable
            # if `PUID`/`PGID` already resolve to a uid/gid that has access to it on the HOST. This
            # points them at bookshelf.nix's own shared `readarr` user/group instead of leaving the
            # default 1000:1000 - the same identity Bookshelf itself runs as (see its own
            # `PUID`/`PGID` comment), which the `books` dataset entry above is chowned to.
            PGID = toString config.users.groups.readarr.gid;
            PUID = toString config.users.users.readarr.uid;
          };

          environmentFiles = [ config.age.secrets."storyteller.env".path ];
          # Next.js's own on-disk cache (`/app/.next/standalone/applications/web/.next/cache`,
          # image-optimization output included) is baked into the image layer, owned by the
          # baked-in `storyteller` user (uid/gid 1000) at build time - and unlike `/data` above,
          # this ISN'T a volume the entrypoint chowns to `PUID`/`PGID` (see the `PUID`/`PGID`
          # comment above), so the process ends up running as `readarr` (uid 31000) against a
          # directory it was never given access to. Podman creates a fresh, empty tmpfs there
          # instead, entirely bypassing the image's baked-in ownership. `mode=1777` (world-
          # writable, sticky) rather than pinning `uid=`/`gid=` to `readarr` - despite those
          # being valid plain tmpfs mount options per mount(8), podman 5.8's own `--tmpfs`/
          # `--mount type=tmpfs` option parser (confirmed on harmony) rejects both with "unknown
          # mount option", so this is the only way left to make it writable by whatever uid the
          # container ends up running as. Losing this on container restart is fine; it's a
          # rebuildable cache, not the app's actual state.
          extraOptions = [ "--tmpfs=/app/.next/standalone/applications/web/.next/cache:mode=1777" ];
          # Pinned to the current `latest` tag's digest at the time this was written --
          # storyteller-platform doesn't cut stable releases, so there's nothing more specific to
          # pin to. Re-resolve via the GitLab registry API if bumping:
          #   curl -s "https://gitlab.com/api/v4/projects/67994333/registry/repositories/8429296/tags/latest"
          image = "registry.gitlab.com/storyteller-platform/storyteller:latest@sha256:f063fcd838ffd9723d581d7a190135069c58c595e6ce9ac41b5e2f8bec090db7";

          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];

          volumes = [
            "/metalminds/storyteller:/data"
            # The shared books library (bookshelf.nix's `/books`), mounted where Storyteller's own
            # docs say its auto-import watcher expects it. Readable/writable without a separate
            # `aclUsers` grant thanks to the `dataset`/`PUID`/`PGID` comments above - Storyteller
            # writes metadata changes back into these files, so this deliberately isn't `:ro`. The
            # watched folder itself still needs pointing at `/library` by hand in Storyteller's own
            # Settings UI - no env var/config-file equivalent for that, same story as
            # `storyteller-oidc-client-secret`'s own comment above.
            "/metalminds/books:/library"
          ];
        };
      };

      secrets = { secrets, ... }: {
        # `intermediary` (unlike immich/nextcloud/seerr's equivalents, which are NOT) - Storyteller
        # keeps its OIDC provider config in its own settings DATABASE, entered through the settings
        # UI, with no env-var or config-file equivalent to point at a decrypted secret. So nothing
        # on the host ever reads this; it exists only to feed Authentik's side via a Terraform
        # `variable` (modules/terranix.nix's two modes), and gets typed into Storyteller by hand -
        # read it back with `agenix view secrets/generated/storyteller-oidc-client-secret.age`.
        storyteller-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = "variable";
        };

        storyteller-secret-key = {
          generator.script = "alnum";
          intermediary = true;
        };

        "storyteller.env".generator = {
          dependencies = { inherit (secrets) storyteller-secret-key; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              # No quotes around %s (unlike an `EnvironmentFile=`-consumed secret would use) - this
              # file is consumed via `environmentFiles` on an oci-containers container, i.e.
              # podman's own `--env-file`, which (unlike systemd's `EnvironmentFile=`, native
              # services' equivalent) does NOT strip surrounding quote characters - a quoted value
              # here would become part of STORYTELLER_SECRET_KEY literally.
              printf 'STORYTELLER_SECRET_KEY=%s\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.storyteller-secret-key.file}
              )"
            '';
        };
      };

      virtual-host = {
        inherit global port url;
        group = "Media";
        homepage.description = "Read-aloud book alignment";
        host = host.name;
        # No dashboard-icons entry for this app - its own upstream logo instead.
        icon = "https://gitlab.com/storyteller-platform/storyteller/-/raw/main/applications/docs/static/img/Storyteller_Logo.png";
        label = "Storyteller";
        name = "storyteller";

        # Deliberately NOT `protected`: Storyteller does its own OIDC login against Authentik via
        # the `oidc` field below, so forward-auth on top would mean logging in twice (once at the
        # outpost, again at Storyteller's own login page) and would break its mobile/OPDS clients,
        # which have no browser session to carry an Authentik cookie.
        #
        # Storyteller is an Auth.js (NextAuth) app mounted at `/api/v2/auth` (`basePath` in
        # applications/web/src/auth/auth.ts), so its callback route is
        # `${AUTH_URL}/callback/${provider-id}`. For a CUSTOM provider that id is derived from the
        # provider's display name - lowercased, spaces to dashes, non-alphanumerics stripped
        # (`customProviderId`, same file) - so the name MUST be entered as "Authentik" in
        # Storyteller's settings for this registered URI to match.
        oidc = {
          client-secret = "storyteller-oidc-client-secret";
          redirect-paths = [ "/api/v2/auth/callback/authentik" ];
        };
      };
    };
}
