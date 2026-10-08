{
  my.unpackerr = { host, ... }: {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        systemd.services.unpackerr = {
          description = "Unpackerr daemon";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];

          serviceConfig = {
            Environment = [
              "UN_SONARR_0_URL=https://sonarr.harmony.${host.domain}"
              "UN_SONARR_0_PATHS_0=/metalminds/torrents/downloads"
              "UN_RADARR_0_URL=https://radarr.harmony.${host.domain}"
              "UN_RADARR_0_PATHS_0=/metalminds/torrents/downloads"
              # Bookshelf is a Readarr fork exposing the same API (see bookshelf.nix), so both of
              # its instances register here as ordinary Readarr entries.
              "UN_READARR_0_URL=https://bookshelf-ebooks.harmony.${host.domain}"
              "UN_READARR_0_PATHS_0=/metalminds/torrents/downloads"
              "UN_READARR_1_URL=https://bookshelf-audiobooks.harmony.${host.domain}"
              "UN_READARR_1_PATHS_0=/metalminds/torrents/downloads"
            ];

            EnvironmentFile = config.age.secrets."unpackerr.env".path;
            ExecStart = lib.getExe pkgs.unpackerr;
            Group = "qbittorrent";
            Restart = "always";
            RestartSec = "5s";
            Type = "simple";
            User = "qbittorrent";
          };

          wants = [ "network-online.target" ];
        };
      };

    secrets = { secrets, ... }: {
      "unpackerr.env".generator = {
        dependencies = {
          inherit (secrets)
            bookshelf-audiobooks-api-key
            bookshelf-ebooks-api-key
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
            printf 'UN_RADARR_0_API_KEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps."radarr-api-key".file})"
            printf 'UN_SONARR_0_API_KEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps."sonarr-api-key".file})"
            printf 'UN_READARR_0_API_KEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps."bookshelf-ebooks-api-key".file})"
            printf 'UN_READARR_1_API_KEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps."bookshelf-audiobooks-api-key".file})"
          '';
      };
    };
  };
}
