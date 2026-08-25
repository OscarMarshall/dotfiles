{
  my.cross-seed = { host, ... }: {
    # `torrentClients` lives in `settings` (plain, Nix-store-visible) rather than `settingsFile`
    # (the encrypted secret) because it no longer carries a credential - qBittorrent's own
    # `AuthSubnetWhitelist` (see qbittorrent.nix) already covers this connection, the same reason
    # the Radarr/Sonarr/Bookshelf download clients don't carry one either. That also means this
    # field, unlike `secrets` below, can safely request the `torrent-client` quirk
    # (torrent-client.nix) directly: nixos/darwin/homeManager module evaluations already declare a
    # real `warnings` option, so Den's collision-validator shim (see modules/terranix.nix's header
    # comment) has somewhere to land - `age.secrets` doesn't, which is exactly why `secrets` below
    # can't do the same.
    nixos =
      {
        config,
        lib,
        pkgs,
        torrent-client,
        ...
      }:
      let
        qbittorrent = lib.findFirst (
          tc: tc.kind == "qbittorrent"
        ) (throw "cross-seed.nix: no qbittorrent torrent-client entry found") torrent-client;
      in
      {
        services.cross-seed = {
          enable = true;

          # better-sqlite3 (pinned to 11.5.0 by cross-seed) segfaults on GC under the default
          # nodejs (24.x) - see https://github.com/NixOS/nixpkgs/issues/553680. Upstream fixed
          # this in https://github.com/NixOS/nixpkgs/pull/556114 by pinning cross-seed's build to
          # nodejs_22, but that fix hasn't reached nixpkgs-unstable yet, so pin it here too.
          #
          # Fires once nixpkgs' unoverridden `cross-seed` itself builds against nodejs_22 (the fix
          # this override works around lands upstream): at that point the override above is dead
          # weight, so drop it (and this assertion) back down to `pkgs.cross-seed`.
          package =
            let
              defaultNodejs = lib.findFirst (
                p: (p.pname or "") == "nodejs" || (p.pname or "") == "nodejs-slim"
              ) (throw "cross-seed.nix: couldn't find cross-seed's nodejs nativeBuildInput") pkgs.cross-seed.nativeBuildInputs;
            in
            assert
              defaultNodejs.version != pkgs.nodejs_22.version
              || throw "my.cross-seed: nixpkgs' unoverridden cross-seed now builds against nodejs ${defaultNodejs.version} (matching nodejs_22) - the nodejs override is no longer needed, remove it.";
            pkgs.cross-seed.override { buildNpmPackage = pkgs.buildNpmPackage.override { nodejs = pkgs.nodejs_22; }; };

          group = "qbittorrent";

          settings = {
            linkDirs = [ "/metalminds/torrents/link-dir" ];
            matchMode = "partial";
            port = 2468;
            torrentClients = [ "qbittorrent:http://${qbittorrent.host}:${toString qbittorrent.port}" ];
          };

          settingsFile = config.age.secrets."cross-seed.json".path;
          useGenConfigDefaults = true;
          user = "qbittorrent";
        };
      };

    secrets = { secrets, ... }: {
      cross-seed-api-key = {
        generator.script = "alnum";
        intermediary = true;
      };

      "cross-seed.json".generator = {
        dependencies = {
          inherit (secrets)
            cross-seed-api-key
            prowlarr-api-key
            radarr-api-key
            sonarr-api-key
            ;
        };

        script =
          {
            lib,
            pkgs,
            decrypt,
            deps,
            ...
          }:
          ''
            CROSS_SEED_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.cross-seed-api-key.file})"
            PROWLARR_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file})"
            RADARR_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.radarr-api-key.file})"
            SONARR_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.sonarr-api-key.file})"

            ${pkgs.jq}/bin/jq -n \
              --arg apiKey "$CROSS_SEED_API_KEY" \
              --arg prowlarrApiKey "$PROWLARR_API_KEY" \
              --arg radarrApiKey "$RADARR_API_KEY" \
              --arg sonarrApiKey "$SONARR_API_KEY" \
              '{
                apiKey: $apiKey,
                torznab: [
                  "https://prowlarr.harmony.${host.domain}/1/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                  "https://prowlarr.harmony.${host.domain}/5/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                  "https://prowlarr.harmony.${host.domain}/9/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                  "https://prowlarr.harmony.${host.domain}/11/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                  "https://prowlarr.harmony.${host.domain}/12/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                  "https://prowlarr.harmony.${host.domain}/13/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                  "https://prowlarr.harmony.${host.domain}/14/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                  "https://prowlarr.harmony.${host.domain}/15/api?apikey=\($prowlarrApiKey)&extended=1&t=search"
                ],
                radarr: [
                  "https://radarr.harmony.${host.domain}?apikey=\($radarrApiKey)"
                ],
                sonarr: [
                  "https://sonarr.harmony.${host.domain}?apikey=\($sonarrApiKey)"
                ]
              }'
          '';
      };
    };
  };
}
