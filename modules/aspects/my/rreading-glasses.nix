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
  # `METADATA_URL` at `http://${name}:${toString port}` (bookshelf.nix) - no fixed IP to track.
  # NixOS's oci-containers module only ever passes whatever's listed in `networks` straight through
  # as `--network=` flags (nixos/modules/virtualisation/oci-containers.nix); it doesn't create the
  # network itself, hence the `podman-network-${network}` oneshot below that every container
  # sharing it (including Bookshelf's own, in bookshelf.nix) depends on.
  network = name;
  # rreading-glasses' own hardcoded default (`PORT` env var, cmd/rghc/main.go) - no reason to
  # override it since, unlike Bookshelf's own two instances, nothing else contends for it: this
  # container is on its own network namespace, not published to the host at all.

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
      # doesn't actually need to match anything inside the container: the official `postgres`
      # image manages its own internal ownership (it runs its entrypoint as real root and
      # chowns `/var/lib/postgresql/data` to its own baked-in `postgres` user itself, regardless
      # of the host-side owner set here) - this is just what `ensureDatasetService` requires a
      # dataset entry to name.
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
          # Fully-qualified (unlike a plain "postgres:17") because harmony's podman has no
          # unqualified-search registries configured - a short name here 125s on
          # `did not resolve to an alias and no unqualified-search registries are defined`.
          # Re-resolve with:
          #   skopeo inspect --override-os linux --override-arch amd64 docker://docker.io/library/postgres:17
          image = "docker.io/library/postgres:17@sha256:67f41722b7a8cbdb868a44a4995c846eddfdc2973bccb291ce937dce88ad5675";
          networks = [ network ];
          volumes = [ "/metalminds/${dbName}:/var/lib/postgresql/data" ];
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
          # Fully-qualified - see the `postgres` image's own comment above for why.
          # Re-resolve with:
          #   skopeo inspect --override-os linux --override-arch amd64 docker://docker.io/blampe/rreading-glasses:hardcover
          image = "docker.io/blampe/rreading-glasses:hardcover@sha256:3f017a51d9007b715303a20f481c822e4df66485fc9e5f57f6fdf1de840dc02f";
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
