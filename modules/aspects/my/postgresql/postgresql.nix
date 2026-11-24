{ lib, ... }: {
  # The host's own `services.postgresql` - shared by every service that keeps its database there
  # (Authentik, Immich, Nextcloud, Paperless, rreading-glasses) - pinned to an explicit major
  # `version` rather than whatever `system.stateVersion` picks, so a major upgrade is a visible
  # change here. Bumping it needs the data pg_upgraded into the new major's directory first (see
  # the NixOS manual's "Upgrading" section of the PostgreSQL chapter - 16 -> 19 was done with a
  # script based on it, in this file's git history); the `preStart` guard below refuses to start
  # rather than silently initdb an empty cluster (that every service would then recreate its
  # database in) if that step was skipped.
  my.postgresql = { version }: {
    nixos =
      { config, pkgs, ... }:
      let
        cfg = config.services.postgresql;
      in
      {
        # nixpkgs marks VectorChord (Immich's vector index) broken on PG 19; until
        # https://github.com/NixOS/nixpkgs/pull/591118 lands, this applies that PR as-is:
        # VectorChord 1.1.1 plus a community PG 19 patch (supervc-stack/VectorChord#464), built
        # with cargo-pgrx 0.19.4. It only patches while nixpkgs still marks the package broken -
        # once nixpkgs fixes it, nixpkgs' own package is used and evaluation warns to delete this
        # overlay. Upstream development has moved to github.com/pgsty/vchord (a drop-in fork
        # Immich is switching to), but its PG 19 release needs pgrx 0.20/Rust 1.100, not in
        # nixpkgs yet.
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
                      stock = pgPrev.passthru.pkgs.vectorchord;
                    in
                    if !(stock.meta.broken or false) then
                      lib.warn "postgresql.nix: nixpkgs no longer marks postgresql19Packages.vectorchord broken - delete the VectorChord overlay and its patches in modules/aspects/my/postgresql/." stock
                    else
                      (stock.override { cargo-pgrx_0_17_0 = cargo-pgrx; }).overrideAttrs (vcPrev: {
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
        # directory is empty. Right after a `version` bump whose data wasn't pg_upgraded first,
        # that would be an EMPTY cluster every service then recreates its database in, while
        # the real data sits in the old major's directory - so refuse instead.
        systemd.services.postgresql.preStart = lib.mkBefore ''
          if ! test -e ${cfg.dataDir}/PG_VERSION && compgen -G '${dirOf cfg.dataDir}/*/PG_VERSION' > /dev/null; then
            echo "Refusing to initdb ${cfg.dataDir}: an older cluster exists in ${dirOf cfg.dataDir} - pg_upgrade it first (see modules/aspects/my/postgresql)." >&2
            exit 1
          fi
        '';
      };
  };
}
