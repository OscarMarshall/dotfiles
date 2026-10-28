{
  lib,
  den,
  my,
  ...
}:
{
  den.aspects.harmony = {
    includes = with my; [
      (authentik { global = true; })
      (auto-upgrade { allowReboot = true; })
      (autobrr { })
      (backup {
        applicationKeyId = "004119677af80560000000002";
        bucket = "coppermind-harmony";
      })
      (beszel { })
      (bookshelf-audiobooks { })
      (bookshelf-ebooks { })
      (cachyos-kernel { variant = "server"; })
      (collabora-online { })
      (docs { global = true; })
      (home-assistant { global = true; })
      (immich {
        administrators = [ "oscar" ];
        global = true;
      })
      (jellyfin { global = true; })
      (nextcloud { global = true; })
      (paperless {
        administrators = [ "oscar" ];
        global = true;
      })
      (plex { global = true; })
      (profilarr { })
      (prowlarr { })
      (qbittorrent { administrators = [ "oscar" ]; })
      (radarr { administrators = [ "oscar" ]; })
      (seerr { global = true; })
      (sonarr { administrators = [ "oscar" ]; })
      (storyteller { global = true; })
      # No `unattended` - see headscale.nix's own header for why harmony bootstraps its own tailnet
      # membership by hand instead of via the same preauth key melaan/tensoon use.
      (tailscale { loginServer = "https://headscale.harmony.silverlight-nex.us"; })
      (tautulli { })
      (zfs [ "metalminds" ])
      boot
      cross-seed
      den.aspects.harmony.provides.minecraft-servers
      dns
      fail2ban
      headscale
      homepage
      lm-sensors
      locale
      mailgun
      meraki
      mousehole
      networkmanager
      nginx
      podman
      rreading-glasses
      samba
      satisfactory-server
      ssh-server
      terranix
      unpackerr
      vpn-confinement
    ];

    # The shared `books` dataset (used by both Bookshelf instances), `movies` (radarr.nix), `shows`
    # (sonarr.nix), `pictures` (immich.nix), `documents` (paperless.nix), and `torrents`
    # (qbittorrent.nix) are declared in their owning aspects instead of here - see bookshelf.nix's
    # own comment on why that's the more correct owner.
    dataset =
      map
        (name: {
          inherit name;
          guestAccess = true;
          pool = "metalminds";
          samba = true;
        })
        [
          "backups"
          "music"
          "yarg-charts"
        ];

    nixos = {
      age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkM5uNY0rMy2QMG6IptlxgVl4sQWoeSSNmUp7/f2z1B";
      networking.hostId = "7dab76c0";

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

      # Lets melaan/tensoon (my.remote-builder) and GitHub Actions (.github/workflows/
      # test.yml) offload builds here over SSH. `openssh.authorizedKeys.keys` is a listOf, so this
      # concatenates with oscar's personal login key from userAspect (oscar.nix) rather than
      # replacing it. Each forced command restricts its key to running the nix-daemon's own
      # worker-protocol server - it can't open an interactive shell even though it authenticates as
      # the (trusted-user) oscar account, which is what lets the daemon accept builds/substitutions
      # from it without further restriction. MUST be `nix-daemon --stdio`, not `nix-store --serve`:
      # both remote-builder.nix and the workflow set `protocol = "ssh-ng"`/use the `ssh-ng://` store
      # URI, which makes the client speak the worker protocol over this same SSH session - `--serve`
      # speaks a different, incompatible protocol and the handshake would just fail.
      #
      # The clients' key is the public half my.remote-builder's generator writes next to its
      # generated secret, so `agenix generate` has to have run before harmony evaluates. CI gets its
      # OWN key (not that one) - a standing credential that lives in GitHub's secret store rather
      # than behind the YubiKey/agenix like every other secret in this repo, so it's kept
      # independently revocable/rotatable without touching the real machines' access.
      users.users.oscar.openssh.authorizedKeys.keys = [
        ''command="nice -n19 nix-daemon --stdio",restrict ${lib.removeSuffix "\n" (builtins.readFile ../../../../secrets/generated/remote-builder-harmony-ssh-key.pub)}''
        ''command="nice -n19 nix-daemon --stdio",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUpLx2LhyMTIrVwH0aWAKg+mav7mBxV1ZrFpN8YKkLT remote-builder-ci@harmony''
      ];
    };

    # This value determines the Home Manager release that your configuration is compatible with. This helps avoid
    # breakage when a new Home Manager release introduces backwards incompatible changes.
    #
    # You can update Home Manager without changing this value. See the Home Manager release notes for a list of state
    # version changes in each release.
    provides.oscar.homeManager.home.stateVersion = "25.05";
  };
}
