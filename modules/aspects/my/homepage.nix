{ my, ... }:
let
  port = 8082;
  port' = toString port;
in
{
  my.homepage = {
    includes = with my; [ (nginx._.virtual-host "harmony.silverlight-nex.us" port) ];

    secrets = { secrets, ... }: {
      "homepage-dashboard.env".generator = {
        dependencies = { inherit (secrets) prowlarr-api-key radarr-api-key sonarr-api-key; };
        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'HOMEPAGE_VAR_PROWLARR_API_KEY="%s"\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file}
            )"
            printf 'HOMEPAGE_VAR_RADARR_API_KEY="%s"\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.radarr-api-key.file}
            )"
            printf 'HOMEPAGE_VAR_SONARR_API_KEY="%s"\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.sonarr-api-key.file}
            )"
          '';
      };
    };

    nixos = { config, ... }: {
      services.homepage-dashboard = {
        enable = true;
        environmentFile = config.age.secrets."homepage-dashboard.env".path;
        allowedHosts = "localhost:${port'},127.0.0.1:${port'},harmony.silverlight-nex.us";
        widgets = [
          {
            glances = {
              url = "http://127.0.0.1:${toString config.services.glances.port}";
              version = 4;
              cputemp = true;
              uptime = true;
              disk = [
                "/"
                "/metalminds"
              ];
              expanded = true;
            };
          }
        ];
        services = [
          {
            "Media" = [
              {
                "Plex" = {
                  href = "https://plex.harmony.silverlight-nex.us";
                  description = "Media server";
                };
              }
            ];
          }
          {
            "Arr Stack" = [
              {
                "Radarr" = {
                  href = "https://radarr.harmony.silverlight-nex.us";
                  description = "Movie organizer/manager";
                  widget = {
                    type = "radarr";
                    url = "https://radarr.harmony.silverlight-nex.us";
                    key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
                    enableQueue = true;
                  };
                };
              }
              {
                "Sonarr" = {
                  href = "https://sonarr.harmony.silverlight-nex.us";
                  description = "Show organizer/manager";
                  widget = {
                    type = "sonarr";
                    url = "https://sonarr.harmony.silverlight-nex.us";
                    key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
                    enableQueue = true;
                  };
                };
              }
              {
                "Prowlarr" = {
                  href = "https://prowlarr.harmony.silverlight-nex.us";
                  description = "Indexer manager/proxy";
                  widget = {
                    type = "prowlarr";
                    url = "https://prowlarr.harmony.silverlight-nex.us";
                    key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
                  };
                };
              }
              {
                "Profilarr" = {
                  href = "https://profilarr.harmony.silverlight-nex.us";
                  description = "Radarr/Sonarr custom format manager";
                };
              }
            ];
          }
        ];
        bookmarks = [
          {
            "Servers" = [
              {
                "Harmony" = [
                  {
                    abbr = "HA";
                    href = "https://harmony.silverlight-nex.us";
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };
}
