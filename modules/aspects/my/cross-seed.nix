{
  my.cross-seed = {
    nixos = { config, ... }: {
      services.cross-seed = {
        enable = true;
        group = "qbittorrent";

        settings = {
          linkDirs = [ "/metalminds/torrents/link-dir" ];
          matchMode = "partial";
          port = 2468;
        };

        settingsFile = config.age.secrets."cross-seed.json".path;
        useGenConfigDefaults = true;
        user = "qbittorrent";
      };
    };

    secrets =
      {
        lib,
        secrets,
        torrent-client,
        ...
      }:
      let
        # See torrent-client.nix - qbittorrent.nix is the one place that knows qBittorrent's real
        # connection details; this just picks the entry and formats it into cross-seed's own
        # `torrentClients` URL shape. No credentials in that URL: cross-seed runs in the default
        # namespace, not qBittorrent's confined one, and reaches it via the namespace's own bridge
        # address - already covered by qBittorrent's `AuthSubnetWhitelist` (see qbittorrent.nix),
        # so its own login is skipped entirely for this connection, the same as for the
        # Radarr/Sonarr/Bookshelf download clients.
        qbittorrent = lib.findFirst (
          tc: tc.kind == "qbittorrent"
        ) (throw "cross-seed.nix: no qbittorrent torrent-client entry found") torrent-client;
      in
      {
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
                --arg qbittorrentHost ${lib.escapeShellArg qbittorrent.host} \
                --arg qbittorrentPort ${lib.escapeShellArg (toString qbittorrent.port)} \
                '{
                  apiKey: $apiKey,
                  torznab: [
                    "https://prowlarr.harmony.silverlight-nex.us/1/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/5/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/9/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/11/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/12/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/13/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/14/api?apikey=\($prowlarrApiKey)&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/15/api?apikey=\($prowlarrApiKey)&extended=1&t=search"
                  ],
                  radarr: [
                    "https://radarr.harmony.silverlight-nex.us?apikey=\($radarrApiKey)"
                  ],
                  sonarr: [
                    "https://sonarr.harmony.silverlight-nex.us?apikey=\($sonarrApiKey)"
                  ],
                  torrentClients: [
                    "qbittorrent:http://\($qbittorrentHost):\($qbittorrentPort)"
                  ]
                }'
            '';
        };
      };
  };
}
