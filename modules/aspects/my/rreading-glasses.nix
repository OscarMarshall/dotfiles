# Self-hosted https://github.com/blampe/rreading-glasses (Hardcover variant) - a caching metadata
# proxy Bookshelf's own `METADATA_URL` (bookshelf.nix) points at instead of the shared community
# instance (`hardcover.bookinfo.pro`), which is currently rate-limited for every Bookshelf install
# using the stock default (see https://github.com/pennydreadful/bookshelf/issues/179 and #180) -
# self-hosting with a personal Hardcover API key gives this install its own quota instead of
# sharing (and contending for) the community one.
#
# Fully internal: no `virtual-host` (it's a JSON metadata API, not something a person browses to)
# and no host port publish at all - it and its Postgres backend only need to be reachable from
# Bookshelf's own containers, which they are via the dedicated `network` (below) all three
# containers join. See that constant's own comment for why a shared podman network is used here
# instead of the loopback-port-publish convention every OTHER service in this repo relies on.
let
  dbName = "${name}-db";
  dbPasswordSecret = "${dbName}-password";
  hardcoverAuthSecret = "${name}-hardcover-auth";
  name = "rreading-glasses";
  # A dedicated podman network (rather than the loopback `ports` publish every other oci-container
  # in this repo uses) because the consumer here is ANOTHER container (Bookshelf), not nginx or
  # some other process running natively on the host - a `127.0.0.1:port:port` publish only binds
  # the HOST's own loopback, which is a distinct network namespace from any other container's, so
  # it wouldn't actually be reachable from Bookshelf's container. Podman's own DNS resolves
  # containers by name for any other container sharing this network, so Bookshelf just points
  # `METADATA_URL` at `http://${name}:8788` (bookshelf.nix, hardcoded there rather than shared from
  # here - see the port comment below) - no fixed IP to track. NixOS's oci-containers module only
  # ever passes whatever's listed in `networks` straight through as `--network=` flags
  # (nixos/modules/virtualisation/oci-containers.nix); it doesn't create the network itself, hence
  # the `podman-network-${network}` oneshot below that every container sharing it (including
  # Bookshelf's own, in bookshelf.nix) depends on.
  network = name;
  # No port option below: 8788 is rreading-glasses' own hardcoded default (`PORT` env var,
  # cmd/rghc/main.go), so nothing here needs to set or forward it - no reason to override it since,
  # unlike Bookshelf's own two instances, nothing else contends for it: this container is on its
  # own network namespace, not published to the host at all. bookshelf.nix's `METADATA_URL` (above)
  # and its own unrelated `port = 8788;` (Bookshelf's own listen port, not this container's) both
  # hardcode the same number independently - there's no shared constant to reference from here.

in
{
  my.rreading-glasses = _: {
    # Only the Postgres backend is stateful - rreading-glasses itself just caches Hardcover
    # responses through it (see its own README: "Metadata is periodically refreshed", "the
    # published image doesn't require any large data dumps and will gradually grow your database
    # as it's queried over time") - safe to lose/rebuild from scratch, so no `dataset` entry (and
    # no backup) for the app container itself, only for `dbName`'s data directory below.
    dataset = [
      {
        # `aclUsers = [ "999" ]` - the postgres image's own baked-in `postgres` user (see the
        # `users.${name}` comment below for the full mechanism this works around). Confirmed live
        # via `podman run --entrypoint bash ... -x docker-entrypoint.sh postgres`: root's own pass
        # `mkdir`s and `chown`s ONLY `$PGDATA` (`/var/lib/postgresql/18/docker`) before re-execing
        # itself as `postgres` (uid 999) via `gosu` - that second pass re-runs
        # `docker_create_db_directories` AS uid 999, which needs to just TRAVERSE the mount point
        # (`/var/lib/postgresql`, this dataset's own root) and its `18/` child to reach the
        # already-chowned `docker/` leaf. Neither of those two directories is `$PGDATA` itself, so
        # root's chown never touches them - they're left with `user`/`group`'s own
        # `rreading-glasses:rreading-glasses` ownership, which grants uid 999 (neither the owner
        # nor a group member) nothing at all: `mkdir: cannot create directory
        # '/var/lib/postgresql': Permission denied` (misleadingly names the mount point itself,
        # since that's where GNU `mkdir -p`'s path-walk first loses the ability to even `stat`
        # deeper). Harmless under the OLD (pre-18) mount scheme - `$PGDATA` there WAS the mount
        # point (`/var/lib/postgresql/data`, no nesting), so root's own chown covered the whole
        # thing every start, matching the `users.${name}` comment below. 18+'s extra nesting level
        # (see `volumes` below) is what exposes this.
        aclUsers = [ "999" ];
        group = name;
        name = dbName;
        pool = "metalminds";
        units = [ "podman-${dbName}" ];
        user = name;
      }
    ];

    nixos = { config, pkgs, ... }: {
      systemd.services = {
        # Both containers below join `network` (rather than the default podman bridge every other
        # container in this repo implicitly gets) so they can resolve each other, and Bookshelf's
        # own containers, by name - see `network`'s own comment above for why.
        "podman-${dbName}" = {
          after = [ "podman-network-${network}.service" ];
          requires = [ "podman-network-${network}.service" ];
        };

        "podman-${name}" = {
          after = [ "podman-network-${network}.service" ];
          requires = [ "podman-network-${network}.service" ];
        };

        "podman-network-${network}" = {
          description = "Ensure the ${network} podman network exists";
          wantedBy = [ "multi-user.target" ];
          # `--ignore`: exits 0 if the network already exists, rather than erroring - this unit
          # re-runs (RemainAfterExit aside, `Requires=` re-triggers a dependency's start any time
          # the depending unit starts) every time any container attached to `network` restarts.
          script = "${pkgs.podman}/bin/podman network create --ignore ${network}";

          serviceConfig = {
            RemainAfterExit = true;
            Type = "oneshot";
          };
        };
      };

      # A dedicated `rreading-glasses` user/group, same reasoning and numbering convention as
      # bookshelf.nix's own `readarr` (31000), satisfactory-server.nix's (31001), and
      # qbittorrent.nix's (31002) - next available id in that sequence. Unlike those, this
      # doesn't actually need to match anything the postgres container itself reads as - the
      # official `postgres` image chowns `$PGDATA` to its own baked-in `postgres` user (uid 999)
      # itself, regardless of the host-side owner set here, on every start (as real root, before
      # dropping to that user) - this is just what `ensureDatasetService` requires a dataset entry
      # to name. See the `dataset` entry's own `aclUsers` comment above for the one thing this
      # self-healing does NOT cover under 18+'s mount layout.
      users = {
        groups.${name}.gid = 31003;

        users.${name} = {
          description = "rreading-glasses (self-hosted Hardcover metadata proxy) service user";
          group = name;
          isSystemUser = true;
          uid = 31003;
        };
      };

      virtualisation.oci-containers.containers = {
        ${dbName} = {
          environment = {
            POSTGRES_DB = name;
            POSTGRES_USER = name;
          };

          environmentFiles = [ config.age.secrets."${dbName}.env".path ];
          # Short name - resolves via podman.nix's `unqualified-search-registries` (docker.io
          # first). Re-resolve with:
          #   skopeo inspect --override-os linux --override-arch amd64 docker://docker.io/library/postgres:18
          #
          # 18+'s image categorically refuses a bind mount landing directly at the old
          # `/var/lib/postgresql/data` - doesn't matter whether it actually holds pre-18 data, an
          # EMPTY mount there still gets rejected (confirmed live: the crash-looped container never
          # got far enough to write anything, yet still hit this). It wants a mount one level up at
          # `/var/lib/postgresql` instead, and creates its own versioned subdirectory
          # (`18/docker`) inside that itself - see https://github.com/docker-library/postgres/pull/1259.
          # This crash-looped when renovate auto-bumped straight from 17 to 18 in place against the
          # old mount path; a future major bump like this one won't auto-merge again - see
          # renovate.json's own major-Docker-image packageRule.
          image = "postgres:18@sha256:10037cee1d5ebfc057cd71b3365466cf27ce8d4bd0c4f409e426fcb2b3fb12e7";
          networks = [ network ];
          volumes = [ "/metalminds/${dbName}:/var/lib/postgresql" ];
        };

        ${name} = {
          cmd = [
            "serve"
            "--verbose"
          ];

          dependsOn = [ dbName ];
          entrypoint = "/main";

          environment = {
            POSTGRES_DATABASE = name;
            POSTGRES_HOST = dbName;
            POSTGRES_USER = name;
          };

          environmentFiles = [
            config.age.secrets."${name}.env".path
            config.age.secrets."${hardcoverAuthSecret}.env".path
          ];

          # README: "The app will use as much memory as it has available for in-memory
          # caching, so it's recommended to run the container with a `--memory` limit" -
          # matches its own reference docker-compose-hardcover.yml's `mem_limit: 128m`.
          extraOptions = [ "--memory=128m" ];
          # Short name - see the `postgres` image's own comment above.
          # Re-resolve with:
          #   skopeo inspect --override-os linux --override-arch amd64 docker://docker.io/blampe/rreading-glasses:hardcover
          image = "blampe/rreading-glasses:hardcover@sha256:3f017a51d9007b715303a20f481c822e4df66485fc9e5f57f6fdf1de840dc02f";
          networks = [ network ];
        };
      };
    };

    secrets = { secrets, ... }: {
      # Shared by both containers below - same password, generated once.
      "${dbName}.env".generator = {
        dependencies = {
          ${dbPasswordSecret} = secrets.${dbPasswordSecret};
        };

        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'POSTGRES_PASSWORD=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.${dbPasswordSecret}.file})"
          '';
      };

      ${dbPasswordSecret} = {
        generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
        intermediary = true;
      };

      # No `generator` on this one - it's a personal credential only a human can obtain (a free
      # Hardcover account's own API token, per https://hardcover.app/account/api), so it's a
      # PRIMITIVE secret: create it with `agenix edit secrets/${hardcoverAuthSecret}.age`,
      # content exactly the bare token (Hardcover's own site tells you to copy "the entire token
      # including Bearer", but the "Bearer " scheme prefix is boilerplate same as `HARDCOVER_AUTH=`
      # below - strip it, just paste what comes after). Then `agenix rekey -a`. Note the token
      # expires every January 1st and needs regenerating.
      #
      # Both the `HARDCOVER_AUTH=` env-file key AND the `Bearer ` auth-scheme prefix are generated
      # (below), same two-layer split as `apiKeySecret` -> `"${name}.env"` in bookshelf.nix - keeps
      # the human-entered secret to just the credential, not also the formatting around it.
      ${hardcoverAuthSecret} = {
        intermediary = true;
        rekeyFile = ../../../secrets/${hardcoverAuthSecret}.age;
      };

      "${hardcoverAuthSecret}.env".generator = {
        dependencies = {
          ${hardcoverAuthSecret} = secrets.${hardcoverAuthSecret};
        };

        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'HARDCOVER_AUTH=Bearer %s\n' "$(${decrypt} ${lib.escapeShellArg deps.${hardcoverAuthSecret}.file})"
          '';
      };

      "${name}.env".generator = {
        dependencies = {
          ${dbPasswordSecret} = secrets.${dbPasswordSecret};
        };

        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'POSTGRES_PASSWORD=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.${dbPasswordSecret}.file})"
          '';
      };
    };
  };
}
