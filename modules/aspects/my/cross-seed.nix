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
      { secrets, ... }:
      let
        # qbittorrentHost/qbittorrentPort below are qbittorrent.nix's hardcoded `namespaceAddress`
        # (its VPN-Confinement namespace's veth address, the same one nginx proxies to) and `port`
        # (8080) - kept as literals rather than read from the `torrent-client` quirk (torrent-client.nix)
        # it's contributed under, because REQUESTING that quirk here (alongside `secrets`) makes Den
        # attach a collision-validator module to the same evalModules pass that builds `age.secrets`,
        # and that validator's `warnings` output collides with `age.secrets` being a flat
        # `attrsOf submodule` - the exact same problem `config` causes here (see modules/terranix.nix's
        # header comment on `warnings-shim`), just triggered by ANY den context arg, not only `config`.
        # There's no shimming this away for the `secrets` class the way terranix.nix does for its own.
        # If either changes in qbittorrent.nix, update it here too.
        #
        # Deliberately not 127.0.0.1: cross-seed runs in the default namespace, not qBittorrent's
        # confined one, and a DNAT redirect from a literal 127.0.0.1 destination to a non-loopback
        # address is silently dropped by the kernel's martian-destination check unless
        # `net.ipv4.conf.*.route_localnet` is set (it isn't) - connecting directly to the namespace's
        # own address sidesteps that entirely, the same way nginx already does.
        #
        # No credentials in the URL below: this connection lands in `192.168.15.0/24`, already
        # covered by qBittorrent's own `AuthSubnetWhitelist` (see qbittorrent.nix), so its login is
        # skipped entirely for it - the same reason the Radarr/Sonarr/Bookshelf download clients
        # don't carry credentials either.
        qbittorrentHost = "192.168.15.1";
        qbittorrentPort = "8080";
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
                --arg qbittorrentHost "${qbittorrentHost}" \
                --arg qbittorrentPort "${qbittorrentPort}" \
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
