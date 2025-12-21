{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./hardware-configuration.nix
    ./cachix.nix
  ];

  age.secrets = {
    autobrr-secret.file = secrets/autobrr-secret.age;
    cross-seed-settings-file.file = secrets/cross-seed-settings-file.age;
    cross-seed-headers-file.file = secrets/cross-seed-headers-file.age;
    gluetun-wireguard-private-key.file = secrets/gluetun-wireguard-private-key.age;
    "homepage-dashboard.env".file = secrets/homepage-dashboard.env.age;
    "minecraft-servers.env".file = secrets/minecraft-servers.env.age;
    "unpackerr.env".file = secrets/unpackerr.env.age;
  };

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "/etc/nixos";
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  boot = {
    kernelModules = [ "coretemp" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "zfs" ];
    zfs = {
      extraPools = [ "metalminds" ];
      forceImportRoot = false;
    };
  };

  networking = {
    hostId = "7dab76c0";
    hostName = "harmony";
    networkmanager.enable = true;
    firewall = {
      allowedTCPPorts = [
        80
        443
        25565
      ];
      allowedUDPPorts = [ 51820 ];
    };
  };

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  users = {
    defaultUserShell = pkgs.zsh;
    groups = {
      qbittorrent.gid = 568;
    };
    users = {
      oscar = {
        description = "Oscar Marshall";
        isNormalUser = true;
        extraGroups = [
          "cross-seed"
          "minecraft"
          "qbittorrent"
          "radarr"
          "sonarr"
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
        ];
        packages = [
          pkgs.rcon-cli
        ];
      };
      qbittorrent = {
        description = "qBittorrent service user";
        isSystemUser = true;
        uid = 568;
        group = "qbittorrent";
        extraGroups = [ "cross-seed" ];
      };
      cross-seed = {
        description = "cross-seed service user";
        isSystemUser = true;
        group = "cross-seed";
        extraGroups = [ "qbittorrent" ];
      };
    };
  };

  nixpkgs = {
    config = {
      allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "minecraft-server"
          "neoforge"
          "plexmediaserver"
        ];
    };
    overlays = [ inputs.nix-minecraft.overlay ];
  };

  environment = {
    systemPackages = [
      pkgs.ddrescue
      pkgs.git
      pkgs.lm_sensors
      pkgs.rclone
      pkgs.wget
    ];
  };

  programs = {
    tmux.enable = true;
    zsh.enable = true;
  };

  virtualisation = {
    oci-containers.containers = {
      gluetun = {
        image = "qmcgaw/gluetun:latest";
        ports = [
          "192.168.15.1:8080:8080" # qBittorrent WebUI
        ];
        volumes = [
          "/metalminds/gluetun:/gluetun"
        ];
        environment = {
          VPN_SERVICE_PROVIDER = "protonvpn";
          VPN_TYPE = "wireguard";
          VPN_PORT_FORWARDING = "on";
          VPN_PORT_FORWARDING_UP_COMMAND = "/bin/sh -c 'wget -O- --retry-connrefused --post-data \"json={\\\"listen_port\\\":{{PORT}},\\\"current_network_interface\\\":\\\"{{VPN_INTERFACE}}\\\",\\\"random_port\\\":false,\\\"upnp\\\":false}\" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'";
          VPN_PORT_FORWARDING_DOWN_COMMAND = "/bin/sh -c 'wget -O- --retry-connrefused --post-data \"json={\\\"listen_port\\\":0,\\\"current_network_interface\\\":\\\"lo\\\"}\" http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1'";
          WIREGUARD_ADDRESSES = "10.2.0.2/32";
          SERVER_COUNTRIES = "US";
          TZ = config.time.timeZone;
        };
        environmentFiles = [ config.age.secrets.gluetun-wireguard-private-key.path ];
        extraOptions = [
          "--cap-add=NET_ADMIN"
          "--device=/dev/net/tun:/dev/net/tun"
        ];
      };
      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:latest";
        volumes = [
          "/var/lib/qBittorrent:/config"
          "/metalminds/torrents/downloads:/downloads"
          "/metalminds/torrents/link-dir:/link-dir"
        ];
        environment = {
          PUID = "568";
          PGID = "568";
          TZ = config.time.timeZone;
          WEBUI_PORT = "8080";
        };
        dependsOn = [ "gluetun" ];
        extraOptions = [
          "--network=container:gluetun"
        ];
      };
      profilarr = {
        image = "santiagosayshey/profilarr:latest";
        ports = [ "127.0.0.1:6868:6868" ];
        volumes = [ "/metalminds/profilarr:/config" ];
        environment = {
          TZ = config.time.timeZone;
        };
      };
      unpackerr = {
        image = "golift/unpackerr";
        volumes = [ "/metalminds/torrents/downloads:/downloads" ];
        environment = {
          TZ = config.time.timeZone;
          UN_SONARR_0_URL = "http://127.0.0.1:${toString config.services.sonarr.settings.server.port}";
          UN_RADARR_0_URL = "http://127.0.0.1:${toString config.services.radarr.settings.server.port}";
        };
        environmentFiles = [ config.age.secrets."unpackerr.env".path ];
      };
    };
  };

  services = {
    apcupsd.enable = true;
    autobrr = {
      enable = true;
      secretFile = config.age.secrets.autobrr-secret.path;
      settings = {
        checkForUpdates = true;
        host = "127.0.0.1";
        port = 7474;
      };
    };
    cross-seed = {
      enable = true;
      user = "cross-seed";
      group = "cross-seed";
      useGenConfigDefaults = true;
      settingsFile = config.age.secrets.cross-seed-settings-file.path;
      settings = {
        port = 2468;
        linkDirs = [ "/metalminds/torrents/link-dir" ];
        matchMode = "partial";
      };
    };
    flaresolverr.enable = true;
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
    minecraft-servers = {
      enable = true;
      openFirewall = true;
      eula = true;
      dataDir = "/metalminds/minecraft-worlds";
      environmentFile = config.age.secrets."minecraft-servers.env".path;
      servers = {
        chicken-house = {
          enable = true;
          package = pkgs.fabricServers.fabric-1_21_8;
          serverProperties = {
            server-port = 25566;
            white-list = true;
            enable-rcon = true;
            "rcon.port" = 25576;
            "rcon.password" = "@RCON_PASSWORD@";
          };
          symlinks = {
            mods = pkgs.linkFarmFromDrvs "mods" (
              builtins.attrValues {
                ArchitecturyAPI = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/XcJm5LH4/architectury-17.0.8-fabric.jar";
                  sha256 = "sha256-tdBR+O/+j5R2+TdeEeSN+vuCF5FDW4/jaIaZADl/BdU=";
                };
                AutoWhitelist = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/BMaqFQAd/versions/PIJ4HDyR/autowhitelist-1.2.4%2B1.21.6.jar";
                  sha256 = "sha256-cYTNxZEGfyUVAkSeFk8Ci3FbcpJOmgeSXqE++NB9BYM=";
                };
                # Carpet = pkgs.fetchurl {
                #   url = "https://cdn.modrinth.com/data/TQTTVgYE/versions/xksYKkvF/fabric-carpet-1.20.2-1.4.121%2Bv231011.jar";
                #   sha256 = "sha256-qGprKkfOVzmNVH/nzOCRC569Q3w7GdxyD6PAoQtji+w=";
                # };
                ClothConfig = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/9s6osm5g/versions/cz0b1j8R/cloth-config-19.0.147-fabric.jar";
                  sha256 = "sha256-2KbcqdDa0f5EYio8agNIZBk045Q8jUJaJvESvObev6I=";
                };
                FabricAPI = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/jjBL6OsN/fabric-api-0.132.0%2B1.21.8.jar";
                  sha256 = "sha256-t2MBX17VRswnCzHspYKty6JkzWKJ5FFF2fU0jGD9olk=";
                };
                FabricLanguageKotlin = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/mccDBWqV/fabric-language-kotlin-1.13.4%2Bkotlin.2.2.0.jar";
                  sha256 = "sha256-KjxW/B3W6SKpvuNaTAukvA2Wd2Py6VL/SbdOw8ZB9Qs=";
                };
                FerriteCore = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/uXXizFIs/versions/CtMpt7Jr/ferritecore-8.0.0-fabric.jar";
                  sha256 = "sha256-K5C/AMKlgIw8U5cSpVaRGR+HFtW/pu76ujXpxMWijuo=";
                };
                Jade = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/o3aatc5Q/Jade-1.21.8-Fabric-19.3.2.jar";
                  sha256 = "sha256-RWjPJiGJqedV9kYagfaypBNCcYF8edVOJB776Y02J9A=";
                };
                Lithium = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/pDfTqezk/lithium-fabric-0.18.0%2Bmc1.21.8.jar";
                  sha256 = "sha256-kBPy+N/t6v20OBddTHZvW0E95WLc0RlaUAIwxVFxeH4=";
                };
                RoughlyEnoughItems = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/nfn13YXA/versions/hoEFy7aF/RoughlyEnoughItems-20.0.811-fabric.jar";
                  sha256 = "sha256-e2t1DkKcRCCF+gdFsDwnOyQiTxzngF2DnrUqmfKwJTo=";
                };
              }
            );
          };
        };
        create-think-bigger = {
          enable = true;
          package = pkgs.neoforgeServers.neoforge-21_1;
          serverProperties = {
            server-port = 25567;
            white-list = true;
            enable-rcon = true;
            "rcon.port" = 25577;
            "rcon.password" = "@RCON_PASSWORD@";
          };
        };
      };
    };
    nginx = {
      enable = true;

      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # Only allow PFS-enabled ciphers with AES256
      sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";

      appendHttpConfig = ''
        # Add HSTS header with preloading to HTTPS requests.
        # Adding this header to HTTP requests is discouraged
        map $scheme $hsts_header {
            https   "max-age=31536000; includeSubdomains; preload";
        }
        add_header Strict-Transport-Security $hsts_header;

        # Enable CSP for your services.
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

        # Minimize information leaked to other domains
        add_header 'Referrer-Policy' 'origin-when-cross-origin';

        # Disable embedding as a frame
        add_header X-Frame-Options DENY;

        # Prevent injection of code in other mime types (XSS Attacks)
        add_header X-Content-Type-Options nosniff;

        # This might create errors
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      '';

      virtualHosts =
        let
          base = locations: {
            inherit locations;

            forceSSL = true;
            enableACME = true;
          };
          proxy =
            port:
            base {
              "/".proxyPass = "http://127.0.0.1:${toString port}/";
            };
          proxyGluetun =
            port:
            base {
              "/".proxyPass = "http://192.168.15.1:${toString port}/";
            };
        in
        {
          "harmony.silverlight-nex.us" = proxy 8082;
          "autobrr.harmony.silverlight-nex.us" = proxy config.services.autobrr.settings.port;
          "plex.harmony.silverlight-nex.us" = proxy 32400;
          "profilarr.harmony.silverlight-nex.us" = proxy 6868;
          "prowlarr.harmony.silverlight-nex.us" = proxy config.services.prowlarr.settings.server.port;
          "qbittorrent.harmony.silverlight-nex.us" = proxyGluetun 8080;
          "radarr.harmony.silverlight-nex.us" = proxy config.services.radarr.settings.server.port;
          "sonarr.harmony.silverlight-nex.us" = proxy config.services.sonarr.settings.server.port;
        };
    };
    openssh = {
      enable = true;
      openFirewall = true;
    };
    plex = {
      enable = true;
      openFirewall = true;
    };
    prowlarr.enable = true;
    radarr.enable = true;
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
    sonarr.enable = true;
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
      trim.enable = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "letsencrypt@alias.oscarmarshall.com";
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or
  # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}
