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
        torrent-client,
        ...
      }:
      let
        qbittorrent = lib.findFirst (
          tc: tc.kind == "qbittorrent"
        ) (throw "cross-seed.nix: no qbittorrent torrent-client entry found") torrent-client;
      in
      {
        # This aspect used to override `services.cross-seed.package` to build against nodejs_22,
        # working around a better-sqlite3 GC segfault under nodejs 24.x
        # (https://github.com/NixOS/nixpkgs/issues/553680). Upstream fixed it the same way in
        # https://github.com/NixOS/nixpkgs/pull/556114, now in nixpkgs-unstable, so the override
        # is gone and plain `pkgs.cross-seed` is used.
        services.cross-seed = {
          enable = true;
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
