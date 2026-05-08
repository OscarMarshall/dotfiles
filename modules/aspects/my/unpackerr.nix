{
  my.unpackerr = {
    secrets =
      { secrets, ... }:
      {
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

    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        users.users.unpackerr = {
          isSystemUser = true;
          group = "unpackerr";
          extraGroups = [ "qbittorrent" ];
        };
        users.groups.unpackerr = { };

        systemd.services.unpackerr = {
          description = "Unpackerr daemon";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            User = "unpackerr";
            Group = "unpackerr";
            EnvironmentFile = config.age.secrets."unpackerr.env".path;
            Environment = [
              "UN_SONARR_0_URL=https://sonarr.harmony.silverlight-nex.us"
              "UN_SONARR_0_PATHS_0=/metalminds/torrents/downloads"
              "UN_RADARR_0_URL=https://radarr.harmony.silverlight-nex.us"
              "UN_RADARR_0_PATHS_0=/metalminds/torrents/downloads"
            ];
            ExecStart = lib.getExe pkgs.unpackerr;
            Restart = "always";
            RestartSec = "5s";
          };
        };
      };
  };
}
