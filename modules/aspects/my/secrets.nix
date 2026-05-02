{ inputs, ... }:
{
  flake-file.inputs = {
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs = {
        agenix.inputs = {
          darwin.follows = "darwin";
          home-manager.follows = "home-manager";
          nixpkgs.follows = "nixpkgs";
          systems.follows = "systems";
        };
        nixpkgs.follows = "nixpkgs";
      };
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  my.secrets.nixos =
    { config, pkgs, lib, ... }:
    {
      imports = [
        (inputs.ragenix.nixosModules.default or { })
        (inputs.agenix-rekey.nixosModules.default or { })
      ];

      age.rekey = {
        masterIdentities = [ ../../../secrets/yubikey-identity.pub ];
        agePlugins = [ pkgs.age-plugin-yubikey ];
        storageMode = "local";
      };

      age.secrets = {
        autobrr-secret.rekeyFile = ../../../secrets/autobrr-secret.age;

        cross-seed-api-key = {
          rekeyFile = ../../../secrets/cross-seed-api-key.age;
          intermediary = true;
        };

        prowlarr-api-key = {
          rekeyFile = ../../../secrets/prowlarr-api-key.age;
          intermediary = true;
        };

        sonarr-api-key = {
          rekeyFile = ../../../secrets/sonarr-api-key.age;
          intermediary = true;
        };

        radarr-api-key = {
          rekeyFile = ../../../secrets/radarr-api-key.age;
          intermediary = true;
        };

        wireguard-private-key = {
          rekeyFile = ../../../secrets/wireguard-private-key.age;
          intermediary = true;
        };

        rcon-password = {
          rekeyFile = ../../../secrets/rcon-password.age;
          intermediary = true;
        };

        qbittorrent-password = {
          rekeyFile = ../../../secrets/qbittorrent-password.age;
          intermediary = true;
        };

        "cross-seed.json" = {
          rekeyFile = ../../../secrets/cross-seed.json.age;
          generator = {
            dependencies = {
              "cross-seed-api-key" = config.age.secrets."cross-seed-api-key";
              "prowlarr-api-key" = config.age.secrets."prowlarr-api-key";
              "sonarr-api-key" = config.age.secrets."sonarr-api-key";
              "radarr-api-key" = config.age.secrets."radarr-api-key";
              "qbittorrent-password" = config.age.secrets."qbittorrent-password";
            };
            script =
              { lib, decrypt, deps, ... }:
              ''
                cross_seed=$(${decrypt} ${lib.escapeShellArg deps."cross-seed-api-key".file})
                prowlarr=$(${decrypt} ${lib.escapeShellArg deps."prowlarr-api-key".file})
                sonarr=$(${decrypt} ${lib.escapeShellArg deps."sonarr-api-key".file})
                radarr=$(${decrypt} ${lib.escapeShellArg deps."radarr-api-key".file})
                qbt=$(${decrypt} ${lib.escapeShellArg deps."qbittorrent-password".file})
                cat <<EOF
                {
                  "apiKey": "$cross_seed",
                  "torznab": [
                    "https://prowlarr.harmony.silverlight-nex.us/1/api?apikey=$prowlarr&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/5/api?apikey=$prowlarr&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/9/api?apikey=$prowlarr&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/11/api?apikey=$prowlarr&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/12/api?apikey=$prowlarr&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/13/api?apikey=$prowlarr&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/14/api?apikey=$prowlarr&extended=1&t=search",
                    "https://prowlarr.harmony.silverlight-nex.us/15/api?apikey=$prowlarr&extended=1&t=search"
                  ],
                  "sonarr": ["https://sonarr.harmony.silverlight-nex.us?apikey=$sonarr"],
                  "radarr": ["https://radarr.harmony.silverlight-nex.us?apikey=$radarr"],
                  "torrentClients": ["qbittorrent:http://oscar:$qbt@127.0.0.1:8080"]
                }
                EOF
              '';
          };
        };

        "gluetun.env" = {
          rekeyFile = ../../../secrets/gluetun.env.age;
          generator = {
            dependencies = {
              "wireguard-private-key" = config.age.secrets."wireguard-private-key";
            };
            script =
              { lib, decrypt, deps, ... }:
              ''
                wg_key=$(${decrypt} ${lib.escapeShellArg deps."wireguard-private-key".file})
                printf 'WIREGUARD_PRIVATE_KEY=%s\n' "$wg_key"
              '';
          };
        };

        "homepage-dashboard.env" = {
          rekeyFile = ../../../secrets/homepage-dashboard.env.age;
          generator = {
            dependencies = {
              "radarr-api-key" = config.age.secrets."radarr-api-key";
              "sonarr-api-key" = config.age.secrets."sonarr-api-key";
              "prowlarr-api-key" = config.age.secrets."prowlarr-api-key";
            };
            script =
              { lib, decrypt, deps, ... }:
              ''
                radarr=$(${decrypt} ${lib.escapeShellArg deps."radarr-api-key".file})
                sonarr=$(${decrypt} ${lib.escapeShellArg deps."sonarr-api-key".file})
                prowlarr=$(${decrypt} ${lib.escapeShellArg deps."prowlarr-api-key".file})
                printf 'HOMEPAGE_VAR_RADARR_API_KEY=%s\n' "$radarr"
                printf 'HOMEPAGE_VAR_SONARR_API_KEY=%s\n' "$sonarr"
                printf 'HOMEPAGE_VAR_PROWLARR_API_KEY=%s\n' "$prowlarr"
              '';
          };
        };

        "minecraft-servers.env" = {
          rekeyFile = ../../../secrets/minecraft-servers.env.age;
          generator = {
            dependencies = {
              "rcon-password" = config.age.secrets."rcon-password";
            };
            script =
              { lib, decrypt, deps, ... }:
              ''
                rcon=$(${decrypt} ${lib.escapeShellArg deps."rcon-password".file})
                printf 'RCON_PASSWORD=%s\n' "$rcon"
              '';
          };
        };

        "qbittorrent.env" = {
          rekeyFile = ../../../secrets/qbittorrent.env.age;
          generator = {
            dependencies = {
              "cross-seed-api-key" = config.age.secrets."cross-seed-api-key";
            };
            script =
              { lib, decrypt, deps, ... }:
              ''
                key=$(${decrypt} ${lib.escapeShellArg deps."cross-seed-api-key".file})
                printf 'CROSS_SEED_API_KEY=%s\n' "$key"
              '';
          };
        };

        "unpackerr.env" = {
          rekeyFile = ../../../secrets/unpackerr.env.age;
          generator = {
            dependencies = {
              "sonarr-api-key" = config.age.secrets."sonarr-api-key";
              "radarr-api-key" = config.age.secrets."radarr-api-key";
            };
            script =
              { lib, decrypt, deps, ... }:
              ''
                sonarr=$(${decrypt} ${lib.escapeShellArg deps."sonarr-api-key".file})
                radarr=$(${decrypt} ${lib.escapeShellArg deps."radarr-api-key".file})
                printf 'UN_SONARR_0_API_KEY=%s\n' "$sonarr"
                printf 'UN_RADARR_0_API_KEY=%s\n' "$radarr"
              '';
          };
        };
      };
    };
}
