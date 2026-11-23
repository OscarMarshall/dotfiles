{ lib, ... }: {
  # The host's own `services.postgresql` - shared by every service that keeps its database there
  # (Authentik, Immich, Nextcloud, Paperless) - pinned to an explicit major `version` rather than
  # whatever `system.stateVersion` picks, so a major upgrade is a visible, two-step change here:
  #
  #   1. Set `upgradeTo` to the new major and deploy. That adds `upgrade-pg-cluster` (below);
  #      run it as root on the host - it stops Postgres and pg_upgrades the data into the new
  #      major's own data directory, leaving the old one untouched.
  #   2. Set `version` to that major, drop `upgradeTo`, and deploy. Postgres starts on the
  #      upgraded data; once everything checks out, run the `delete_old_cluster.sh` pg_upgrade
  #      left behind.
  #
  # Deploying step 2 without having run step 1 is refused rather than silently starting an empty
  # cluster (and letting every service recreate its database in it) - see the `preStart` guard.
  my.postgresql =
    {
      version,
      upgradeTo ? null,
    }:
    {
      nixos =
        { config, pkgs, ... }:
        let
          cfg = config.services.postgresql;

          upgrade-pg-cluster =
            let
              # Same extension list as the running cluster (`cfg.extensions` takes the package
              # set to pick from), built for the new major - pg_upgrade needs every library the
              # old cluster uses to exist on the new side too.
              new = pkgs."postgresql_${upgradeTo}".withPackages cfg.extensions;
              newData = "${dirOf cfg.dataDir}/${new.psqlSchema}";
              preload = cfg.settings.shared_preload_libraries or null;
            in
            pkgs.writeShellApplication {
              name = "upgrade-pg-cluster";
              runtimeInputs = [ pkgs.util-linux ];

              text = ''
                if [ "$(id -u)" != 0 ]; then
                  echo "upgrade-pg-cluster: run as root" >&2
                  exit 1
                fi

                old_data=${lib.escapeShellArg cfg.dataDir}
                old_bin=${cfg.finalPackage}/bin
                new_data=${lib.escapeShellArg newData}
                new_bin=${new}/bin
                work=${lib.escapeShellArg "${dirOf cfg.dataDir}/upgrade-${cfg.package.psqlSchema}-to-${new.psqlSchema}"}
                as_pg() { runuser -u ${cfg.superUser} -- "$@"; }

                if [ -e "$new_data/PG_VERSION" ]; then
                  echo "upgrade-pg-cluster: $new_data already holds a cluster - remove it to retry" >&2
                  exit 1
                fi

                if ! systemctl is-active --quiet postgresql.service; then
                  echo "upgrade-pg-cluster: postgresql.service must be running (its settings are read first)" >&2
                  exit 1
                fi

                # pg_upgrade requires the new cluster's encoding/locale and checksum setting to
                # match the old one's, so read them off the old cluster rather than trusting
                # whatever initdb would default to now (PG 18+ enables checksums by default).
                read -r encoding collate ctype provider < <(
                  as_pg "$old_bin/psql" -Atq -F ' ' -c \
                    "SELECT pg_encoding_to_char(encoding), datcollate, datctype, datlocprovider FROM pg_database WHERE datname = 'template0'"
                )

                if [ "$provider" != c ]; then
                  echo "upgrade-pg-cluster: old cluster uses locale provider '$provider', only libc ('c') is handled" >&2
                  exit 1
                fi

                checksum_version=$(as_pg "$old_bin/pg_controldata" "$old_data" | sed -n 's/^Data page checksum version: *//p')

                if [ "$checksum_version" = 0 ]; then
                  checksums=--no-data-checksums
                else
                  checksums=--data-checksums
                fi

                echo "Old cluster: $encoding, collate=$collate, ctype=$ctype, checksums=$checksum_version"

                systemctl stop postgresql.target postgresql.service

                install -d -m 0700 -o ${cfg.superUser} -g ${cfg.superUser} "$new_data" "$work"
                cd "$work"

                as_pg "$new_bin/initdb" -D "$new_data" -U ${cfg.superUser} \
                  --encoding="$encoding" --locale-provider=libc --lc-collate="$collate" --lc-ctype="$ctype" \
                  "$checksums" ${lib.escapeShellArgs cfg.initdbArgs}

                pg_upgrade=(
                  "$new_bin/pg_upgrade"
                  --old-datadir "$old_data" --new-datadir "$new_data"
                  --old-bindir "$old_bin" --new-bindir "$new_bin"
                  --username ${cfg.superUser}
                  ${lib.optionalString (preload != null)
                    # The old cluster gets this from the NixOS-managed postgresql.conf symlinked into
                    # its data directory; the fresh one only has initdb's defaults. VectorChord
                    # refuses to load at all unless preloaded.
                    "--new-options ${lib.escapeShellArg "-c shared_preload_libraries=${lib.concatStringsSep "," (lib.toList preload)}"}"
                  }
                )

                as_pg "''${pg_upgrade[@]}" --check "$@"
                as_pg "''${pg_upgrade[@]}" "$@"

                echo
                echo "Done. The old cluster at $old_data is untouched and Postgres is still stopped."
                echo "Next: deploy with version = \"${new.psqlSchema}\" (modules/aspects/my/postgresql), then follow"
                echo "pg_upgrade's instructions above; its scripts are in $work."
              '';
            };
        in
        {
          environment.systemPackages = lib.optional (upgradeTo != null) upgrade-pg-cluster;

          # TODO: drop once https://github.com/NixOS/nixpkgs/pull/591118 is in nixpkgs-unstable
          # (eval warns once vectorchord moves past 1.1.1 - check then). nixpkgs marks VectorChord
          # broken on PG 19; this applies that PR as-is: VectorChord 1.1.1 plus a community PG 19
          # patch (supervc-stack/VectorChord#464), built with cargo-pgrx 0.19.4. Upstream
          # development has moved to github.com/pgsty/vchord (a drop-in fork Immich is switching
          # to), but its PG 19 release needs pgrx 0.20/Rust 1.100, not in nixpkgs yet - and staying
          # on 1.1.1 keeps the extension's own version unchanged across pg_upgrade.
          nixpkgs.overlays = [
            (final: prev: {
              postgresql_19 = prev.postgresql_19.overrideAttrs (pgPrev: {
                passthru = pgPrev.passthru // {
                  pkgs = pgPrev.passthru.pkgs // {
                    vectorchord =
                      let
                        cargo-pgrx = prev.cargo-pgrx_0_19_1.overrideAttrs (pgrxPrev: rec {
                          cargoDeps = final.rustPlatform.fetchCargoVendor {
                            inherit src;
                            hash = "sha256-ZUxcx6AXzv5IahiKl3YfqPh9A9PL/QbL6qcGBdp/hNc=";
                          };

                          src = final.fetchCrate {
                            inherit version;
                            hash = "sha256-ePwf0BrzjZGlYda8OBIZ15QBTtbDEu7I69lF/llA1v4=";
                            pname = "cargo-pgrx";
                          };

                          version = "0.19.4";
                        });

                        cargoPatches = [
                          ./vectorchord-pg19.patch
                          # pgrx 0.18+ embeds schema metadata in the library, replacing pgrx_embed.
                          ./pgrx-0.18-migration.patch
                        ];
                      in
                      (pgPrev.passthru.pkgs.vectorchord.override { cargo-pgrx_0_17_0 = cargo-pgrx; }).overrideAttrs (vcPrev: {
                        cargoDeps = final.rustPlatform.fetchCargoVendor {
                          inherit (vcPrev) src;
                          hash = "sha256-GmINtHWVikgSga/1IsFMyyFEooebnjHtpEZH7CoOxm0=";
                          patches = cargoPatches;
                        };

                        patches = cargoPatches ++ vcPrev.patches;

                        meta = vcPrev.meta // {
                          broken = false;
                        };
                      });
                  };
                };
              });
            })
          ];

          services.postgresql.package = pkgs."postgresql_${version}";

          # NixOS's own preStart initdb's a fresh cluster whenever the configured major's data
          # directory is empty. Right after a `version` bump that skipped `upgrade-pg-cluster`,
          # that would be an EMPTY cluster every service then recreates its database in, while
          # the real data sits in the old major's directory - so refuse instead.
          systemd.services.postgresql.preStart = lib.mkBefore ''
            if ! test -e ${cfg.dataDir}/PG_VERSION && compgen -G '${dirOf cfg.dataDir}/*/PG_VERSION' > /dev/null; then
              echo "Refusing to initdb ${cfg.dataDir}: an older cluster exists in ${dirOf cfg.dataDir} - run upgrade-pg-cluster first (see modules/aspects/my/postgresql)." >&2
              exit 1
            fi
          '';
        };
    };
}
