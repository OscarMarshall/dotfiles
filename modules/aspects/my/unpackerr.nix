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
          after = [ "network-online.target" ];
          description = "Unpackerr daemon";
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
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
        };
      };
    secrets = { secrets, ... }: {
      "unpackerr.env".generator = {
        dependencies = { inherit (secrets) radarr-api-key sonarr-api-key; };
        script =
          {
            decrypt,
            deps,
            lib,
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
