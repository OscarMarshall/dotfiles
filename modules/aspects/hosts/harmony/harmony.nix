{ my, ... }:
{
  den.aspects.harmony = {
    includes = with my; [
      (auto-upgrade { allowReboot = true; })
      autobrr
      boot
      (cachyos-kernel { variant = "server-lto"; })
      cross-seed
      gluetun
      homepage
      lm-sensors
      locale
      (minecraft-servers { administrators = [ "oscar" ]; })
      networkmanager
      nginx
      plex
      profilarr
      prowlarr
      (qbittorrent { administrators = [ "oscar" ]; })
      (radarr { administrators = [ "oscar" ]; })
      (samba "/metalminds" [
        "backups"
        "documents"
        "minecraft-worlds"
        "movies"
        "music"
        "pictures"
        "shows"
        "torrents"
        "yarg-charts"
      ])
      secrets
      (sonarr { administrators = [ "oscar" ]; })
      ssh-server
      unpackerr
      (zfs [ "metalminds" ])
    ];

    nixos = {
      networking.hostId = "7dab76c0";

      age.rekey = {
        hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkM5uNY0rMy2QMG6IptlxgVl4sQWoeSSNmUp7/f2z1B";
        localStorageDir = ./secrets;
      };

      services = {
        apcupsd.enable = true;
        glances.enable = true;
      };

      # This option defines the first version of NixOS you have installed on this particular machine, and is used to
      # maintain compatibility with application data (e.g. databases) created on older NixOS versions.
      #
      # Most users should NEVER change this value after the initial install, for any reason, even if you've upgraded
      # your system to a new NixOS release.
      #
      # This value does NOT affect the Nixpkgs version your packages and OS are pulled from, so changing it will NOT
      # upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how to actually do that.
      #
      # This value being lower than the current NixOS release does NOT mean your system is out of date, out of support,
      # or vulnerable.
      #
      # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
      # and migrated your data accordingly.
      #
      # For more information, see `man configuration.nix` or
      # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
      system.stateVersion = "25.05"; # Did you read the comment?
    };

    # This value determines the Home Manager release that your configuration is compatible with. This helps avoid
    # breakage when a new Home Manager release introduces backwards incompatible changes.
    #
    # You can update Home Manager without changing this value. See the Home Manager release notes for a list of state
    # version changes in each release.
    provides.oscar.homeManager.home.stateVersion = "25.05";
  };
}
