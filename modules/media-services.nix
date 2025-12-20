{ config, pkgs, ... }:

{
  virtualisation = {
    oci-containers.containers = {
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
          UN_SONARR_0_URL = "http://192.168.15.1:${toString config.services.sonarr.settings.server.port}";
          UN_RADARR_0_URL = "http://192.168.15.1:${toString config.services.radarr.settings.server.port}";
        };
        environmentFiles = [ config.age.secrets."unpackerr.env".path ];
      };
    };
  };

  services = {
    autobrr = {
      enable = true;
      secretFile = config.age.secrets.autobrr-secret.path;
      settings = {
        checkForUpdates = true;
        host = "192.168.15.1";
        port = 7474;
      };
    };
    cross-seed = {
      enable = true;
      user = config.services.qbittorrent.user;
      group = config.services.qbittorrent.group;
      useGenConfigDefaults = true;
      settingsFile = config.age.secrets.cross-seed-settings-file.path;
      settings = {
        port = 2468;
        linkDirs = [ "/metalminds/torrents/link-dir" ];
        matchMode = "partial";
      };
    };
    flaresolverr.enable = true;
    plex = {
      enable = true;
      openFirewall = true;
    };
    prowlarr.enable = true;
    qbittorrent = {
      enable = true;
      package = pkgs.qbittorrent-nox;
      serverConfig = {
        AutoRun = {
          enabled = true;
          program = ''
            ${pkgs.curl}/bin/curl -XPOST http://127.0.0.1:${toString config.services.cross-seed.settings.port}/api/webhook \
              -H \"@${config.age.secrets.cross-seed-headers-file.path}\" \
              -d \"infoHash=%I\" \
              -d \"includeSingleEpisodes=true\"
          '';
        };
        BitTorrent.Session = {
          DefaultSavePath = "/metalminds/torrents/downloads";
          IgnoreSlowTorrentsForQueueing = true;
          MaxActiveTorrents = 999999999;
          MaxActiveUploads = 999999999;
          Tags = "cross-seed";
        };
        Preferences.WebUI = {
          Password_PBKDF2 = "@ByteArray(3+DJBBGQhl1i7uYQ4PAZAA==:FTHL6psR2VpGAUnpsh/SlTa5mPjZZ6ab6YwkzqH0JxUL94iDPCKHFpkZQoAqnlv/0rri76zKo6on73kwI3s7dA==)";
          ReverseProxySupportEnabled = true;
          TrustedReverseProxiesList = "qbittorrent.harmony.silverlight-nex.us";
          Username = "oscar";
        };
      };
    };
    radarr.enable = true;
    sonarr.enable = true;
  };

  systemd.services = {
    autobrr.vpnConfinement = {
      enable = true;
      vpnNamespace = "proton0";
    };
    cross-seed.vpnConfinement = {
      enable = true;
      vpnNamespace = "proton0";
    };
    flaresolverr.vpnConfinement = {
      enable = true;
      vpnNamespace = "proton0";
    };
    prowlarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "proton0";
    };
    qbittorrent.vpnConfinement = {
      enable = true;
      vpnNamespace = "proton0";
    };
    radarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "proton0";
    };
    sonarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "proton0";
    };
  };
}
