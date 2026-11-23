# Self-hosted https://github.com/blampe/rreading-glasses (Hardcover variant) - a caching metadata
# proxy Bookshelf's own `METADATA_URL` (bookshelf.nix) points at instead of the shared community
# instance (`hardcover.bookinfo.pro`), which is currently rate-limited for every Bookshelf install
# using the stock default (see https://github.com/pennydreadful/bookshelf/issues/179 and #180) -
# self-hosting with a personal Hardcover API key gives this install its own quota instead of
# sharing (and contending for) the community one.
#
# Fully internal: no `virtual-host` (it's a JSON metadata API, not something a person browses to)
# and no host port publish at all - it only needs to be reachable from Bookshelf's own containers,
# which it is via the dedicated `network` (below) they all join. See that constant's own comment
# for why a shared podman network is used here instead of the loopback-port-publish convention
# every OTHER service in this repo relies on.
#
# Its database lives in the host's native `services.postgresql` (the same instance authentik,
# immich, nextcloud and paperless use), reached over the Unix socket rather than a second Postgres
# container. It's only a cache of Hardcover responses (README: "Metadata is periodically
# refreshed", "will gradually grow your database as it's queried over time"), so it's on the root
# disk with no dataset and no backup - safe to lose and rebuild from scratch.
let
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
  socketDir = "/run/postgresql";

in
{
  my.rreading-glasses = {
    nixos = { config, pkgs, ... }: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ name ];

        ensureUsers = [
          {
            inherit name;
            ensureDBOwnership = true;
          }
        ];
      };

      systemd.services = {
        # `postgresql.target` (not just `postgresql.service`) - it also covers `postgresql-setup`,
        # which is what actually creates the `ensureUsers`/`ensureDatabases` role and database.
        # Joins `network` (rather than the default podman bridge every other container in this repo
        # implicitly gets) so Bookshelf's own containers can resolve it by name - see `network`'s
        # own comment above for why.
        "podman-${name}" = {
          after = [
            "podman-network-${network}.service"
            "postgresql.target"
          ];

          requires = [
            "podman-network-${network}.service"
            "postgresql.target"
          ];
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

        # `socketDir` is postgresql.service's own `RuntimeDirectory`, which systemd deletes on every
        # stop and recreates on start by default - a NEW directory, invisible to the container's
        # bind mount below (still pinned to the old, deleted one), so any Postgres restart (e.g. a
        # nixpkgs bump changing its package) would cut this container off until it's restarted
        # too. Keeping the directory lets Postgres recreate its socket inside the same one, and
        # pgx's pool just reconnects.
        postgresql.serviceConfig.RuntimeDirectoryPreserve = "yes";
      };

      # A dedicated `rreading-glasses` user/group, same numbering convention as bookshelf.nix's own
      # `readarr` (31000), satisfactory-server.nix's (31001), and qbittorrent.nix's (31002) - next
      # available id in that sequence. The container runs as this uid (`user` below) so Postgres's
      # default `local all all peer` rule maps the socket connection to the `rreading-glasses` role
      # by OS username - no password to generate or store. That only works because podman here is
      # rootful with no user-namespace remapping: the uid inside the container IS the host uid
      # Postgres sees on the socket.
      users = {
        groups.${name}.gid = 31003;

        users.${name} = {
          description = "rreading-glasses (self-hosted Hardcover metadata proxy) service user";
          group = name;
          isSystemUser = true;
          uid = 31003;
        };
      };

      virtualisation.oci-containers.containers.${name} = {
        cmd = [
          "serve"
          "--verbose"
        ];

        entrypoint = "/main";

        environment = {
          POSTGRES_DATABASE = name;
          # An absolute path makes rreading-glasses treat it as a Unix socket directory and drop
          # the port from its DSN (`PGConfig.DSN`, cmd/root.go).
          POSTGRES_HOST = socketDir;
          # Never checked - peer auth ignores it. Still needed: the DSN is always built as
          # `password=%s dbname=%s ...`, and pgx reads an EMPTY `password=` as swallowing the next
          # `dbname=...` token as the password instead.
          POSTGRES_PASSWORD = "unused";
          POSTGRES_USER = name;
        };

        environmentFiles = [ config.age.secrets."${hardcoverAuthSecret}.env".path ];
        # README: "The app will use as much memory as it has available for in-memory
        # caching, so it's recommended to run the container with a `--memory` limit" -
        # matches its own reference docker-compose-hardcover.yml's `mem_limit: 128m`.
        extraOptions = [ "--memory=128m" ];
        # Short name - resolves via podman.nix's `unqualified-search-registries` (docker.io
        # first). Re-resolve with:
        #   skopeo inspect --override-os linux --override-arch amd64 docker://docker.io/blampe/rreading-glasses:hardcover
        image = "blampe/rreading-glasses:hardcover@sha256:3f017a51d9007b715303a20f481c822e4df66485fc9e5f57f6fdf1de840dc02f";
        networks = [ network ];
        user = "${toString config.users.users.${name}.uid}:${toString config.users.groups.${name}.gid}";
        # The whole directory, not just the socket file - Postgres recreates the socket on every
        # restart, which a file-level bind mount would keep pointing at the old, deleted inode. The
        # directory itself must survive too - see `RuntimeDirectoryPreserve` above.
        volumes = [ "${socketDir}:${socketDir}" ];
      };
    };

    secrets = { secrets, ... }: {
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
    };
  };
}
