{ config, ... }:

{
  services = {
    apcupsd.enable = true;
    glances.enable = true;
    homepage-dashboard = {
      enable = true;
      environmentFile = config.age.secrets."homepage-dashboard.env".path;
      allowedHosts = "localhost:8082,127.0.0.1:8082,harmony.silverlight-nex.us";
      widgets = [
        {
          glances = {
            url = "http://127.0.0.1:61208";
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
    openssh = {
      enable = true;
      openFirewall = true;
    };
    samba = {
      enable = true;
      settings =
        let
          commonShareAttrs = {
            "guest ok" = "yes";
            "read only" = "yes";
            "write list" = "@users";
            "browsable" = "yes";
          };
          shareList = [
            "backups"
            "documents"
            "minecraft-worlds"
            "movies"
            "music"
            "pictures"
            "shows"
            "torrents"
            "yarg-charts"
          ];
          generatedShares = builtins.listToAttrs (
            map (share: {
              name = share;
              value = commonShareAttrs // {
                path = "/metalminds/${share}";
              };
            }) shareList
          );
        in
        {
          global = {
            "map to guest" = "Bad User";
          };
          processing = {
            path = "/metalminds/processing";
            "write list" = "@users";
            "browsable" = "yes";
          };
        }
        // generatedShares;
      openFirewall = true;
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
      trim.enable = true;
    };
  };
}
