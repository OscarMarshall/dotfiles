{
  my.cross-seed = {
    secrets =
      { config, secrets, ... }:
      {
        cross-seed-api-key = {
          generator.script = "alnum";
          intermediary = true;
        };
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
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              PROWLARR_API_KEY="$(${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file})"
              cat <<EOF
              {
                "apiKey": "$(${decrypt} ${lib.escapeShellArg deps.cross-seed-api-key.file})",
                "torznab": [
                  "https://prowlarr.harmony.silverlight-nex.us/1/api?apikey=$PROWLARR_API_KEY&extended=1&t=search",
                  "https://prowlarr.harmony.silverlight-nex.us/5/api?apikey=$PROWLARR_API_KEY&extended=1&t=search",
                  "https://prowlarr.harmony.silverlight-nex.us/9/api?apikey=$PROWLARR_API_KEY&extended=1&t=search",
                  "https://prowlarr.harmony.silverlight-nex.us/11/api?apikey=$PROWLARR_API_KEY&extended=1&t=search",
                  "https://prowlarr.harmony.silverlight-nex.us/12/api?apikey=$PROWLARR_API_KEY&extended=1&t=search",
                  "https://prowlarr.harmony.silverlight-nex.us/13/api?apikey=$PROWLARR_API_KEY&extended=1&t=search",
                  "https://prowlarr.harmony.silverlight-nex.us/14/api?apikey=$PROWLARR_API_KEY&extended=1&t=search",
                  "https://prowlarr.harmony.silverlight-nex.us/15/api?apikey=$PROWLARR_API_KEY&extended=1&t=search"
                ],
                "radarr": ["https://radarr.harmony.silverlight-nex.us?apikey=$(
                  ${decrypt} ${lib.escapeShellArg deps.radarr-api-key.file}
                )"],
                "sonarr": ["https://sonarr.harmony.silverlight-nex.us?apikey=$(
                  ${decrypt} ${lib.escapeShellArg deps.sonarr-api-key.file}
                )"],
                "torrentClients": ["qbittorrent:http://oscar:$(
                  ${decrypt} ${lib.escapeShellArg deps.oscar-password.file}
                )@127.0.0.1:${config.virtualisation.oci-containers.containers.qbittorrent.environment.WEBUI_PORT}"]
              }
              EOF
            '';
        };
      };

    nixos =
      { config, ... }:
      {
        services.cross-seed = {
          enable = true;
          user = "qbittorrent";
          group = "qbittorrent";
          useGenConfigDefaults = true;
          settingsFile = config.age.secrets."cross-seed.json".path;
          settings = {
            port = 2468;
            linkDirs = [ "/metalminds/torrents/link-dir" ];
            matchMode = "partial";
          };
        };
      };
  };
}
