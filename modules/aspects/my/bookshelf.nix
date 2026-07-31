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
      dataset = {
        inherit name;
        pool = "metalminds";
      };

      nixos = { config, pkgs, ... }: {
        # LinuxServer's own init fixes up `/config`'s ownership to match PUID/PGID automatically,
        # but never touches other bind-mounted volumes - `/books` (shared by both instances, see
        # its own comment below) is just whatever `zfs create` left it as (root-owned), which the
        # container's own PUID/PGID-mapped user then can't write to without this.
        #
        # A plain `systemd.tmpfiles.rules` entry does NOT work here: `systemd-tmpfiles-setup.service`
        # runs `Before = [ "sysinit.target" ]`, but ZFS datasets (this repo's `metalminds` pool is
        # `boot.zfs.extraPools`, not the root filesystem) are mounted by `zfs-mount.service`, which
        # is only `wantedBy = [ "zfs.target" ]` and `zfs.target` is only `wantedBy = [
        # "multi-user.target" ]` - reached long after sysinit.target. A tmpfiles rule targeting
        # `/metalminds/books` would run BEFORE that mount exists, creating (and chowning) a plain
        # directory on the root filesystem that the later ZFS mount then shadows - the real
        # dataset's root keeps whatever `zfs create` left it as, permission error unchanged.
        # `RequiresMountsFor` is the actual fix: it resolves to whatever mount unit covers a path
        # at runtime (no need to name `zfs-mount.service`/a synthesized per-dataset mount unit
        # directly) and orders this unit after it.
        systemd.services."chown-metalminds-books" = {
          description = "Fix /metalminds/books ownership for Bookshelf";
          before = [ "podman-${name}.service" ];
          requiredBy = [ "podman-${name}.service" ];

          serviceConfig = {
            ExecStart = "${pkgs.coreutils}/bin/chown readarr:readarr /metalminds/books";
            RemainAfterExit = true;
            Type = "oneshot";
          };

          unitConfig.RequiresMountsFor = [ "/metalminds/books" ];
        };

        # A dedicated `readarr` user/group (shared by BOTH Bookshelf instances, same as
        # qbittorrent.nix's own service user) rather than accepting the image's own undocumented
        # built-in "abc" (911:911) - both instances' containers run as this user via PUID/PGID
        # below, so whichever one writes to the shared `/books` root folder, the other can too.
        # `uid`/`gid` are pinned explicitly (983, the next one down from
        # satisfactory-server.nix's 984 and qbittorrent.nix's 985) rather than left to NixOS's own
        # dynamic system-user allocation, which only resolves a UID at activation time - too late
        # to bake into the container's own PUID/PGID env vars below, which need a value at build
        # time.
        users = {
          groups.readarr.gid = 983;

          users.readarr = {
            description = "Bookshelf (Readarr) service user";
            group = "readarr";
            isSystemUser = true;
            uid = 983;
          };
        };

        virtualisation.oci-containers.containers.${name} = {
          environment = {
            # Matches the `chown-metalminds-books` service above and the dedicated `readarr`
            # user/group declared alongside it.
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

          # `/books` is shared by BOTH instances deliberately (see harmony.nix's `books` dataset) -
          # the plan is for the ebook and audiobook instance to manage the same on-disk library for
          # a given book, eventually kept in sync the way
          # https://trash-guides.info/Radarr/Tips/Sync-2-radarr-sonarr/ describes for Radarr/Sonarr
          # pairs - not implemented yet, tracked as a follow-up.
          volumes = [
            "/metalminds/${name}:/config"
            "/metalminds/books:/books"
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
      terranix =
        {
          lib,
          host,
          torrent-client,
          ...
        }:
        let
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

          variable."${tf-var-name-of apiKeySecret}".sensitive = true;
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
