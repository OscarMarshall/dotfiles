# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "/etc/nixos";
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };

  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;

  # Use the systemd-boot EFI boot loader.
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

  fileSystems = {
    "/silverlight" = {
      device = "silverlight:/home/oscar";
      fsType = "rclone";
      options = [
        "nodev"
        "nofail"
        "allow_other"
        "args2env"
        "config=/etc/rclone-silverlight.conf"
        "x-systemd.automount"
      ];
    };
  };

  networking = {
    hostId = "7dab76c0";
    hostName = "harmony";
    networkmanager.enable = true;
    firewall = {
      #allowedTCPPorts = [ 6868 ];
      # allowedUDPPorts = [ ... ];
    };
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    # useXkbConfig = true; # use xkb.options in tty.
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      oscar = {
        description = "Oscar Marshall";
        isNormalUser = true;
        extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
        ];
        packages = [
          #pkgs.tree
        ];
      };
    };
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
    "plexmediaserver"
  ];


  environment = {
    # List packages installed in system profile.
    # You can use https://search.nixos.org/ to find more packages (and options).
    systemPackages = [
      pkgs.ddrescue
      pkgs.git
      pkgs.lm_sensors
      pkgs.rclone
      pkgs.wget
    ];
    etc."rclone-silverlight.conf".text = ''
      [silverlight]
      type = sftp
      host = triton.usbx.me
      user = oscar
      key_file = /root/.ssh/id_ed25519
      shell_type = unix
    '';
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs = {
    tmux.enable = true;
    zsh.enable = true;
  };

  virtualisation.oci-containers.containers = {
    profilarr = {
      image = "santiagosayshey/profilarr:latest"; # or :beta
      ports = [ "6868:6868" ];
      volumes = [ "/metalminds/profilarr:/config" ];
      environment = { TZ = config.time.timeZone; };
    };
  };

  # List services that you want to enable:
  services = {
    apcupsd.enable = true;
    flaresolverr = {
      enable = true;
      openFirewall = true;
    };
    homepage-dashboard = {
      enable = true;
      openFirewall = true;
      allowedHosts = "localhost:8082,127.0.0.1:8082,10.10.10.16:8082";
      services = [
        {
          "Media" = [
            {
              "Plex" = {
                href = "http://10.10.10.16:32400";
                description = "Media server";
              };
            }
          ];
        }
        {
          "Arr Stack" = [
            {
              "Radarr" = {
                href = "http://10.10.10.16:7878";
                description = "Movie organizer/manager";
              };
            }
            {
              "Prowlarr" = {
                href = "http://10.10.10.16:9696";
                description = "Indexer manager/proxy";
              };
            }
            {
              "Profilarr" = {
                href = "http://10.10.10.16:6868";
              };
            }
          ];
        }
        {
          "Ultra.cc" = [
            {
              "Control Panel" = {
                href = "cp.ultra.cc";
                description = "Ultr.cc Control Panel";
              };
            }
            {
              "qBittorrent" = {
                href = "https://oscar.triton.usbx.me/qbittorrent";
                description = "Torrent client";
              };
            }
          ];
        }
      ];
    };
    openssh = {
      enable = true; # Enable the OpenSSH daemon.
      openFirewall = true;
    };
    plex = {
      enable = true;
      openFirewall = true;
    };
    prowlarr = {
      enable = true;
      openFirewall = true;
    };
    radarr = {
      enable = true;
      openFirewall = true;
      group = "users";
    };
    samba = {
      enable = true;
      settings = let
        commonShareAttrs = {
          "guest ok" = "yes";
          "read only" = "yes";
          "write list" = "@users";
          "browsable" = "yes";
        };
        shareList = ["backups" "documents" "movies" "music" "pictures" "shows" "torrents" "yarg-charts"];
        generatedShares = builtins.listToAttrs (map
          (share: { name = share; value = commonShareAttrs // { path = "/metalminds/${share}"; }; })
          shareList
        );
      in
        {
          global = {
            "map to guest" = "Bad User";
          };
        } // generatedShares;
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

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

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
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}

