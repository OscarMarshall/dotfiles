# preservation - declarative persistent state on top of an ephemeral root.
#
# On tensoon `/` is tmpfs and `/home` is a btrfs subvolume reset to an empty snapshot on every
# boot (see rollback-home below and modules/aspects/hosts/tensoon/disk.nix). Everything that must
# survive a reboot is listed here and bind-mounted (or symlinked) from `/persist`.
#
# The user list below is oscar-specific; generalise it if another host ever adopts this aspect.
{ inputs, ... }: {
  # preservation's flake takes no inputs (the module uses the consumer's pkgs), so there is no
  # nixpkgs to make follow.
  flake-file.inputs.preservation.url = "github:nix-community/preservation";

  my.preservation.nixos = { pkgs, ... }: {
    imports = [ inputs.preservation.nixosModules.default ];

    boot.initrd.systemd = {
      enable = true;
      initrdBin = [ pkgs.btrfs-progs ];

      # Reset the @home subvolume to the pristine @home-blank snapshot before /home is mounted.
      # @home-blank is created once during install (see the plan's walkthrough).
      services.rollback-home = {
        description = "Reset /home to a pristine btrfs snapshot";
        wantedBy = [ "initrd.target" ];
        after = [ "systemd-cryptsetup@cryptroot.service" ];
        before = [ "sysroot-home.mount" ];
        requires = [ "systemd-cryptsetup@cryptroot.service" ];

        script = ''
          set -euo pipefail

          mkdir -p /btrfs_tmp
          mount -o subvol=/ /dev/mapper/cryptroot /btrfs_tmp
          # Always release the temporary top-level mount, even if a btrfs op below fails and
          # aborts the script (better an emergency shell than a half-wiped @home).
          trap 'umount /btrfs_tmp' EXIT

          if [ -e /btrfs_tmp/@home ]; then
            btrfs subvolume list -o /btrfs_tmp/@home | cut -f9- -d' ' | while read -r sub; do
              btrfs subvolume delete "/btrfs_tmp/$sub"
            done
            btrfs subvolume delete /btrfs_tmp/@home
          fi

          btrfs subvolume snapshot /btrfs_tmp/@home-blank /btrfs_tmp/@home
        '';

        serviceConfig.Type = "oneshot";
        unitConfig.DefaultDependencies = "no";
      };
    };

    preservation = {
      enable = true;

      preserveAt."/persist" = {
        directories = [
          # NixOS uid/gid map - losing this reassigns user/group IDs.
          {
            directory = "/var/lib/nixos";
            inInitrd = true;
          }

          "/var/log"
          "/var/lib/systemd" # random-seed, timers, backlight, rfkill, coredump
          "/var/lib/bluetooth" # pairings
          "/var/lib/fprint" # enrolled fingerprints
          "/var/lib/upower" # battery history
          "/var/lib/power-profiles-daemon" # last selected profile
          "/var/lib/NetworkManager" # DHCP leases, secret_key, timestamps
          "/var/lib/AccountsService" # user metadata / avatars (greeter)
          "/var/lib/cups" # configured printers
          "/var/lib/noctalia-greeter" # sync.toml (wallpaper/palette from "Sync Now")

          {
            directory = "/etc/NetworkManager/system-connections";
            mode = "0700";
          } # saved Wi-Fi
        ];

        files = [
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
          {
            configureParent = true;
            file = "/etc/ssh/ssh_host_ed25519_key";
            how = "symlink";
          }
          {
            configureParent = true;
            file = "/etc/ssh/ssh_host_ed25519_key.pub";
            how = "symlink";
          }
          {
            configureParent = true;
            file = "/etc/ssh/ssh_host_rsa_key";
            how = "symlink";
          }
          {
            configureParent = true;
            file = "/etc/ssh/ssh_host_rsa_key.pub";
            how = "symlink";
          }
        ];

        users.oscar = {
          directories = [
            {
              directory = ".ssh";
              mode = "0700";
            } # holds id_ed25519 (home-manager age key)
            {
              directory = ".gnupg";
              mode = "0700";
            }
            {
              directory = ".local/share/keyrings";
              mode = "0700";
            } # libsecret / gnome-keyring

            ".local/share/fish" # shell history
            ".local/state/nix" # per-user nix profile (incl. home-manager generations)
            ".local/state/home-manager" # hm gcroots / news-read state
            ".local/state/wireplumber" # per-device audio volume/routing
            ".local/share/direnv" # direnv allow-list
            ".local/share/nix" # trusted-settings.json
            ".config/noctalia" # Noctalia GUI-mutable settings + custom palettes
            ".config/discord"
            ".claude" # Claude Code: project memory, history, todos
            ".zen" # zen-browser profile
            ".local/share/proton-pass" # Proton Pass agent DB + key (verify path on first run)

            # Large; drop if you will not game on this machine.
            ".local/share/Steam"
            ".steam"
          ];

          # Bind-mounted (not symlinked, no configureParent): preservation already creates
          # /persist/home/oscar via its home-dir rule, and adding a configureParent rule for the
          # same path collides with that rule's mode (homeMode "700" vs parent default "0755").
          files = [ ".claude.json" ]; # Claude Code auth + config
        };
      };
    };

    systemd = {
      # /etc/machine-id is bind-mounted, so the commit service (which expects to persist a tmpfs
      # machine-id) has nothing to do and would fail.
      suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

      # preservation already recreates /home/oscar and the parent dirs of every persisted path
      # (owned by oscar). ~/.cache isn't a parent of anything persisted, so create it here so
      # first-run cache writes (fontconfig, mesa, thumbnails) don't race against a missing dir.
      tmpfiles.settings.preservation."/home/oscar/.cache".d = {
        group = "users";
        mode = "0700";
        user = "oscar";
      };
    };
  };
}
