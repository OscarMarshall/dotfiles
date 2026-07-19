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
    secrets = { secrets, ... }: {
      cross-seed-api-key = {
        generator.script = "alnum";
        intermediary = true;
      };
      # webuiPort below is qbittorrent.nix's hardcoded `port` (8080) - kept as a literal rather
      # than read from `config` because requesting `config` on this field (alongside `secrets`)
      # makes Den attach a collision-validator module to the same evalModules pass that builds
      # `age.secrets`, and that validator's `warnings` output collides with `age.secrets` being a
      # flat `attrsOf submodule` (unlike terranix's allowlisted JSON schema, there's no shimming
      # this away - see modules/terranix.nix). If qbittorrent's port ever changes, update it here
      # too.
      "cross-seed.json".generator = {
        dependencies = {
          inherit (secrets)
            cross-seed-api-key
            oscar-password
            prowlarr-api-key
            radarr-api-key
            sonarr-api-key
            ;
        };
        script =
          {
            decrypt,
            deps,
            lib,
            pkgs,
            ...
          }:
          ''
            CROSS_SEED_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.cross-seed-api-key.file})"
            PROWLARR_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file})"
            RADARR_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.radarr-api-key.file})"
            SONARR_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.sonarr-api-key.file})"
            QBITTORRENT_PASSWORD="$(${decrypt} ${lib.escapeShellArg deps.oscar-password.file})"

            ${pkgs.jq}/bin/jq -n \
              --arg apiKey "$CROSS_SEED_API_KEY" \
              --arg prowlarrApiKey "$PROWLARR_API_KEY" \
              --arg radarrApiKey "$RADARR_API_KEY" \
              --arg sonarrApiKey "$SONARR_API_KEY" \
              --arg qbittorrentPassword "$QBITTORRENT_PASSWORD" \
              --arg webuiPort "8080" \
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
                  "qbittorrent:http://oscar:\($qbittorrentPassword)@127.0.0.1:\($webuiPort)"
                ]
              }'
          '';
      };
    };
  };
}
