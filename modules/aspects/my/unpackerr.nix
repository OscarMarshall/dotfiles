{
  my.unpackerr = {
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
              "UN_SONARR_0_URL=https://sonarr.harmony.silverlight-nex.us"
              "UN_SONARR_0_PATHS_0=/metalminds/torrents/downloads"
              "UN_RADARR_0_URL=https://radarr.harmony.silverlight-nex.us"
              "UN_RADARR_0_PATHS_0=/metalminds/torrents/downloads"
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
        dependencies = { inherit (secrets) radarr-api-key sonarr-api-key; };

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
          '';
      };
    };
  };
}
