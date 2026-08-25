{ lib, ... }:
let
  # Matches virtual-host.nix's own derived hostname (`${name}.${host.name}.<domain>`) - no shared
  # domain constant exists in this repo (authentik.nix/dns.nix/nginx.nix each carry this same
  # literal), so this matches that convention rather than introducing one.
  domain = "silverlight-nex.us";
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
      apiKeySecret = "${name}-api-key";
      name = "bookshelf-${instance}";
    in
    {
      # The `dataset` quirk (zfs.nix) aggregates across contributors, so this instance contributes
      # a LIST: its own `/config` dataset, AND the `/books` one shared with the OTHER Bookshelf
      # instance - both instances declare the exact same `books` entry (harmless: `ensureDatasetService`
      # only reads `pool`/`name`/`user`/`group`, identical either way, so the resulting
      # zfs-dataset-metalminds-books.service is the same regardless of which contribution "wins"
      # the name; each instance's own `units` entry for it still gets unioned in). Living here
      # (rather than on harmony.nix's own host-level `dataset` list, where it used to be) keeps
      # Bookshelf's own user/group/unit names out of the host aspect, which has no other reason to
      # know them.
      dataset = [
        {
          inherit name;
          # Owned by the same dedicated `readarr` user/group declared below - the container runs as
          # readarr via PUID/PGID, and needs write access to its own `/config`.
          group = "readarr";
          pool = "metalminds";
          # This instance's own container needs its `/config` dataset to actually exist (and be
          # mounted) before it starts - see zfs.nix's own `units` field comment.
          units = [ "podman-${name}" ];
          user = "readarr";
        }
        {
          # Owned by a dedicated `readarr` user/group (declared below) shared by BOTH instances, so
          # whichever one writes to it, the other can too.
          group = "readarr";
          guestAccess = true;
          name = "books";
          pool = "metalminds";
          samba = true;
          units = [ "podman-${name}" ];
          user = "readarr";
        }
      ];

      nixos = { config, ... }: {
        # A dedicated `readarr` user/group (shared by BOTH Bookshelf instances, same as
        # qbittorrent.nix's own service user) rather than accepting the image's own undocumented
        # built-in "abc" (911:911) - both instances' containers run as this user via PUID/PGID
        # below, so whichever one writes to the shared `/books` root folder, the other can too.
        # `uid`/`gid` are pinned explicitly rather than left to NixOS's own dynamic system-user
        # allocation, which only resolves an id at activation time - too late to bake into the
        # container's own PUID/PGID env vars below, which need a value at build time. Pinned to
        # 31000 (alongside satisfactory-server.nix's 31001 and qbittorrent.nix's 31002) rather than
        # some number under 1000: NixOS's dynamic allocator (nixos/modules/config/update-users-groups.pl)
        # only ever draws from 400-999 (system users/groups) and 1000-29999 (normal users), so
        # anything >= 30000 can never collide with an id it hands out - unlike this trio's previous
        # 983/984/985, which happened to land inside that first range and collided in practice: both
        # nix-minecraft's dynamically-allocated `minecraft` group and the unrelated `mandb` system
        # user ended up sharing 984 with satisfactory-server.nix's old pin. 30000-30032 is ALSO
        # reserved (statically, not dynamically) for Nix's own `nixbld`/`nixbld1..32` build users
        # (`ids.uids.nixbld`) - hence starting this block at 31000 rather than 30000 itself.
        users = {
          groups.readarr.gid = 31000;

          users.readarr = {
            description = "Bookshelf (Readarr) service user";
            group = "readarr";
            isSystemUser = true;
            uid = 31000;
          };
        };

        virtualisation.oci-containers.containers.${name} = {
          environment = {
            # Matches the shared `readarr` user/group declared alongside it, which
            # `zfs-dataset-metalminds-books.service` (see the shared `books` entry in `dataset`
            # above and zfs.nix's generic consumer) chowns the shared `/books` root folder to.
            PGID = toString config.users.groups.readarr.gid;
            PUID = toString config.users.users.readarr.uid;
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
            # Bookshelf/Readarr listens on its own hardcoded default port (8787) regardless of the
            # host-side port it's mapped to below - without this, only the ebooks instance (which
            # happens to use 8787 itself) works by accident, and the audiobooks instance (8788)
            # gets a connection refused (nginx 502) because nothing's actually listening on 8788
            # inside its container.
            READARR__SERVER__PORT = toString port;
          };

          environmentFiles = [ config.age.secrets."${name}.env".path ];
          # `--group-add` (rather than PGID above, which only sets the primary group) makes the
          # container process a supplementary member of qbittorrent's own group, the same way
          # radarr.nix's/sonarr.nix's own native `radarr`/`sonarr` users get
          # `extraGroups = [ "qbittorrent" ];` - qBittorrent writes completed downloads as
          # qbittorrent:qbittorrent, so importing them needs read access to that group.
          extraOptions = [ "--group-add=${toString config.users.groups.qbittorrent.gid}" ];
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

          # `/books` is shared by BOTH instances deliberately (see the shared `books` entry in
          # `dataset` above) - the plan is for the ebook and audiobook instance to manage the same
          # on-disk library for a given book, eventually kept in sync the way
          # https://trash-guides.info/Radarr/Tips/Sync-2-radarr-sonarr/ describes for Radarr/Sonarr
          # pairs - not implemented yet, tracked as a follow-up.
          #
          # `/metalminds/torrents/downloads` is mounted at the SAME absolute path (rather than a
          # container-local alias like `/downloads`) so Bookshelf sees completed downloads at
          # exactly the path qBittorrent itself reports them at (both radarr.nix/sonarr.nix and
          # unpackerr.nix already rely on this same path directly, being native processes with no
          # container boundary to translate across) - avoids needing a Remote Path Mapping in
          # Bookshelf's own settings to reconcile two different paths for the same file.
          volumes = [
            "/metalminds/${name}:/config"
            "/metalminds/books:/books"
            "/metalminds/torrents/downloads:/metalminds/torrents/downloads"
          ];
        };
      };

      secrets = { secrets, ... }: {
        ${apiKeySecret} = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
          settings.terraform = "variable";
        };

        "${name}.env".generator = {
          dependencies = {
            ${apiKeySecret} = secrets.${apiKeySecret};
          };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              # No quotes around %s (unlike radarr.env/sonarr.env's own printf) - this file is
              # consumed via `environmentFiles` on an oci-containers container, i.e. podman's own
              # `--env-file`, which (unlike systemd's `EnvironmentFile=`, native services'
              # equivalent) does NOT strip surrounding quote characters - a quoted value here would
              # become part of the API key literally, corrupting the Bookshelf frontend's own
              # `/initialize.json` payload once it re-serializes that value into JSON.
              printf 'READARR__AUTH__APIKEY=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.${apiKeySecret}.file})"
            '';
        };
      };

      # Root folder, managed via terranix (Nix -> Terraform config, see modules/terranix.nix) and
      # the devopsarr/readarr provider - same pattern as radarr.nix/sonarr.nix, but ALIASED
      # (`provider.readarr` is a LIST here, one entry per Bookshelf instance, merged across both
      # instances' own `terranix` fields - terranix's `provider` option supports this, see
      # https://den.denful.dev/tutorials/terranix-demo/) since both instances share the one
      # `readarr` provider TYPE but are two entirely separate live instances - every resource below
      # pins itself to its own alias via `provider = "readarr.${instance}";`.
      #
      # `${apiKeySecret}` is flagged `settings.terraform = "variable";` for the same two-role reason
      # radarr-api-key/sonarr-api-key are (see radarr.nix's `terranix` field) - Prowlarr's
      # `prowlarr_application_readarr` (prowlarr.nix) needs it as a plain resource attribute too,
      # not just as this provider's own auth.
      #
      # This resource already exists by hand in the running instance; applying without importing
      # first would create a duplicate (same situation `authentik_outpost.embedded` was in - see
      # authentik.nix's comment on that resource). One-time, via `nix develop .#<host>-tf`
      # (AUTHENTIK_TOKEN-style env sourcing is automatic, see modules/terranix.nix's `prefixText`):
      #
      #   tofu import readarr_root_folder.${instance} <id>  # GET /api/v1/rootfolder
      #
      # `default_metadata_profile_id`/`default_quality_profile_id` are pinned to `1` - both
      # instances are brand new, and a fresh Readarr/Bookshelf database ships with exactly one
      # profile of each, at id 1. Adjust (or import) if that's no longer true by the time this
      # applies.
      #
      # The qBittorrent download client below is built from the `torrent-client` quirk
      # (torrent-client.nix) - qbittorrent.nix is the one place that knows its real connection
      # details; this aspect just picks the entry and formats it into the
      # `readarr_download_client_qbittorrent` shape (`book_category` is Readarr's own field name
      # for this - see radarr.nix's/sonarr.nix's own `terranix` fields for their equivalents).
      # `book_category` is `instance`-scoped (distinct per Bookshelf instance), unlike the shared
      # `/books` root folder above - each instance still needs its own qBittorrent category so a
      # completed download only gets imported by the app that actually requested it, rather than
      # both instances racing to import anything tagged "books".
      #
      #   tofu import readarr_download_client_qbittorrent.${instance} <id>  # GET /api/v1/downloadclient
      #
      # `readarr_naming` turns on file renaming (`rename_books`) - Terraform requires the other
      # naming fields alongside it regardless (the resource covers Readarr's whole Media Management
      # > naming settings, not just the toggle), so they're pinned to Readarr's own stock defaults
      # rather than left to chance: `{Author Name}` folders, `{Author Name} - {Book Title}` files,
      # smart colon replacement, illegal characters replaced.
      #
      #   tofu import readarr_naming.${instance} <id>  # GET /api/v1/config/naming
      #
      # `readarr_import_list_readarr` is the actual sync mechanism from
      # https://trash-guides.info/Radarr/Tips/Sync-2-radarr-sonarr/ - despite the name, that guide
      # is Radarr/Sonarr-specific text describing a GENERIC Servarr feature: pointing one instance's
      # own native Import List at the OTHER instance's API (its own periodic refresh, no
      # webhook/custom-script needed), so anything added to either side gets mirrored to the other.
      # Both instances get one, each pointed at its sibling, for full bidirectional sync -
      # `enable_automatic_add`/`should_search` mirror the guide's "full sync" variant (everything,
      # automatically). `quality_profile_id`/`metadata_profile_id` are pinned to `1` for the same
      # reason `readarr_root_folder`'s own default profile ids are above.
      #
      #   tofu import readarr_import_list_readarr.${instance} <id>  # GET /api/v1/importlist
      terranix =
        {
          lib,
          host,
          torrent-client,
          ...
        }:
        let
          otherApiKeySecret = "bookshelf-${otherInstance}-api-key";
          otherInstance = if instance == "audiobooks" then "ebooks" else "audiobooks";
          qbittorrent = lib.findFirst (
            tc: tc.kind == "qbittorrent"
          ) (throw "bookshelf.nix: no qbittorrent torrent-client entry found") torrent-client;
        in
        {
          provider.readarr = [
            {
              alias = instance;
              api_key = "\${var.${tf-var-name-of apiKeySecret}}";
              url = "https://${name}.${host.name}.${domain}";
            }
          ];

          resource = {
            readarr_download_client_qbittorrent.${instance} = {
              inherit (qbittorrent) host;
              inherit (qbittorrent) port;
              enable = true;
              book_category = instance;
              book_imported_category = "${instance}-imported";
              name = "qBittorrent";
              priority = 1;
              provider = "readarr.${instance}";
            };

            readarr_import_list_readarr.${instance} = {
              api_key = "\${var.${tf-var-name-of otherApiKeySecret}}";
              base_url = "https://bookshelf-${otherInstance}.${host.name}.${domain}";
              enable_automatic_add = true;
              metadata_profile_id = 1;
              monitor_new_items = "all";
              name = "Sync from Bookshelf (${otherInstance})";
              provider = "readarr.${instance}";
              quality_profile_id = 1;
              root_folder_path = "/books";
              # "specificBook" (not "all" - the provider's actual enum here is
              # `["none" "specificBook" "entireAuthor"]`, confirmed via `tofu validate`) monitors
              # only the book(s) this list actually adds - "entireAuthor" would balloon monitoring
              # to that author's whole back-catalog on the sibling instance the moment any one of
              # their books syncs over, which isn't the intent (mirror what's there, not expand it).
              should_monitor = "specificBook";
              should_monitor_existing = true;
              should_search = true;
            };

            readarr_naming.${instance} = {
              author_folder_format = "{Author Name}";
              colon_replacement_format = 4; # Smart
              provider = "readarr.${instance}";
              rename_books = true;
              replace_illegal_characters = true;
              # Must contain Book Title AND PartNumber, OR Original Title (confirmed via a real
              # `tofu apply` 400) - this is Readarr's own default format.
              standard_book_format = "{Book Title}/{Author Name} - {Book Title}{ (PartNumber)}";
            };

            readarr_root_folder.${instance} = {
              default_metadata_profile_id = 1;
              default_monitor_new_item_option = "all";
              default_monitor_option = "all";
              default_quality_profile_id = 1;
              is_calibre_library = false;
              name = "Books";
              # Readarr's own API validates `output_profile` as a non-empty enum even though it's
              # only meaningful for a Calibre library (`is_calibre_library = false` above) - leaving
              # it unset sends "" (the provider's own default for an omitted optional+computed
              # string), which that validator rejects outright ("has a range of values which does
              # not include ''"). "default" is a real value in Calibre's own output-profile enum and
              # is simply inert here since this isn't a Calibre library.
              output_profile = "default";
              path = "/books";
              provider = "readarr.${instance}";
            };
          };

          terraform.required_providers.readarr = {
            source = "devopsarr/readarr";
            version = "~> 2.1";
          };

          variable = {
            # `otherApiKeySecret`'s variable is also declared by the OTHER instance's own `terranix`
            # field (as ITS `apiKeySecret`) - redeclared here too, defensively, matching
            # prowlarr.nix's own reasoning for RADARR_API_KEY/SONARR_API_KEY (identical
            # `sensitive = true;` definitions merge fine, not a conflict).
            "${tf-var-name-of apiKeySecret}".sensitive = true;
            "${tf-var-name-of otherApiKeySecret}".sensitive = true;
          };
        };

      virtual-host = {
        inherit global name port;
        # Bookshelf (Readarr) serves its own REST API under /api; nginx.nix lets that through the
        # Authentik forward-auth gate untouched since Prowlarr's Applications sync
        # (prowlarr.nix's `prowlarr_application_readarr` resources) calls it directly with an API
        # key, machine-to-machine, with no browser session to carry an Authentik cookie - same
        # reasoning as radarr.nix/sonarr.nix/prowlarr.nix's own `bypassAuthPaths`.
        bypassAuthPaths = [ "^/api" ];
        group = "Arr Stack";
        homepage = { inherit description; };
        host = host.name;
        # No dashboard-icons entry for pennydreadful/bookshelf specifically (its "audiobookshelf"
        # entry is a different, unrelated app) - its own upstream logo instead. Named Readarr.svg
        # upstream since Bookshelf is a Readarr fork.
        icon = "https://raw.githubusercontent.com/pennydreadful/bookshelf/develop/Logo/Readarr.svg";
        label = "Bookshelf (${label})";
        protected = true;
        # Bookshelf's UI keeps a SignalR (WebSocket) connection open for live queue/activity
        # updates (it's a Readarr fork, same mechanism) - without this, nginx's
        # recommendedProxySettings clears the Connection header (see nginx.nix's
        # `proxyWebsockets` comment) and the upgrade is refused.
        websockets = true;
      };
    };
  # Mirrors `env-var-for` (modules/terranix.nix) exactly - the `TF_VAR_` prefix a
  # `settings.terraform = "variable";` secret surfaces under is added programmatically there, not
  # baked into the secret's name.
  tf-var-name-of = secret: lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] secret);
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
