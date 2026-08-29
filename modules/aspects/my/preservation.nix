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

  my.preservation.nixos =
    { pkgs, ... }:
    let
      # Manage those snapshots from a running system (list is unprivileged; rm/prune need root).
      homeSnapshots = pkgs.writeShellApplication {
        name = "tensoon-home-snapshots";

        runtimeInputs = [
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.findutils
        ];

        text = ''
          set -euo pipefail

          dir=/mnt/btrfs/@home-snapshots
          keep=${toString keepHomeSnapshots}
          names() { find "$dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort; }

          case "''${1:-list}" in
            list)
              if [ -d "$dir" ]; then names; fi
              ;;
            rm)
              if [ "$#" -ne 2 ]; then
                echo "usage: tensoon-home-snapshots rm <timestamp>" >&2
                exit 2
              fi
              btrfs subvolume delete "$dir/$2"
              ;;
            prune)
              n=''${2:-$keep}
              names | head -n "-$n" | while read -r s; do
                btrfs subvolume delete "$dir/$s"
              done
              ;;
            *)
              echo "usage: tensoon-home-snapshots {list | rm <timestamp> | prune [keep]}" >&2
              exit 2
              ;;
          esac
        '';
      };
      # rollback-home snapshots @home read-only before wiping it and keeps this many of the newest
      # snapshots, pruning the rest every boot. `tensoon-home-snapshots prune` reuses this default.
      # Recover a file with e.g. `sudo cp -a /mnt/btrfs/@home-snapshots/<stamp>/wanted/path ~/`.
      keepHomeSnapshots = 5;
    in
    {
      imports = [ inputs.preservation.nixosModules.default ];

      # preservation forces systemd-in-initrd, which makes agenix decrypt during
      # `initrd-nixos-activation` - before `/etc/ssh/ssh_host_ed25519_key` (a stage-2 tmpfs symlink)
      # exists, so it finds "no readable identities" and every secret fails. `/persist` is
      # `neededForBoot` and mounted by then, so add the persisted host keys as identities; the
      # `/etc/ssh` defaults still cover the stage-2 run.
      age.identityPaths = [
        "/persist/etc/ssh/ssh_host_ed25519_key"
        "/persist/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_rsa_key"
      ];

      boot.initrd.systemd = {
        enable = true;

        initrdBin = [
          pkgs.btrfs-progs
          pkgs.coreutils
        ];

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
            # aborts the script.
            trap 'umount /btrfs_tmp' EXIT

            # First boot / recovery: nothing can have written to @home yet (this runs before /home is
            # ever mounted), so if it's missing, recreate it empty and seed @home-blank from it. This
            # makes the manual "snapshot @home-blank during install" step unnecessary and lets a lost
            # @home self-heal instead of dropping to emergency.
            if [ ! -e /btrfs_tmp/@home ]; then
              btrfs subvolume create /btrfs_tmp/@home
              [ -e /btrfs_tmp/@home-blank ] || btrfs subvolume snapshot -r /btrfs_tmp/@home /btrfs_tmp/@home-blank
            fi

            # If the blank snapshot is gone but @home already exists (and may hold data), leave it
            # alone rather than wiping to nothing.
            if [ ! -e /btrfs_tmp/@home-blank ]; then
              echo "rollback-home: @home-blank missing; leaving @home as-is" >&2
              exit 0
            fi

            # Keep the outgoing /home as a read-only snapshot before it is wiped, so anything that
            # should have been in my.preservation but wasn't is still recoverable (this is how a lost
            # ~/Repositories would have been saved). Non-recursive: contents of any nested subvolume
            # under /home are not captured. Then prune to the newest ${toString keepHomeSnapshots}.
            mkdir -p /btrfs_tmp/@home-snapshots
            stamp=$(date -u +%Y%m%dT%H%M%SZ)
            if [ -e "/btrfs_tmp/@home-snapshots/$stamp" ]; then stamp="$stamp-$$"; fi
            btrfs subvolume snapshot -r /btrfs_tmp/@home "/btrfs_tmp/@home-snapshots/$stamp"
            ls -1 /btrfs_tmp/@home-snapshots | sort | head -n -${toString keepHomeSnapshots} | while read -r old; do
              btrfs subvolume delete "/btrfs_tmp/@home-snapshots/$old"
            done

            btrfs subvolume list -o /btrfs_tmp/@home | cut -f9- -d' ' | while read -r sub; do
              btrfs subvolume delete "/btrfs_tmp/$sub"
            done
            btrfs subvolume delete /btrfs_tmp/@home
            btrfs subvolume snapshot /btrfs_tmp/@home-blank /btrfs_tmp/@home
          '';

          serviceConfig.Type = "oneshot";
          unitConfig.DefaultDependencies = "no";
        };
      };

      environment.systemPackages = [ homeSnapshots ];

      # Top-level btrfs view so tensoon-home-snapshots and manual `cp` recovery can reach the
      # @home-snapshots/ subvolumes that rollback-home writes. `nofail` keeps a hiccup here from
      # blocking boot.
      fileSystems."/mnt/btrfs" = {
        options = [
          "subvol=/"
          "noatime"
          "nofail"
        ];

        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
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

              # Local git clones. Preserved outright (not just snapshotted) so uncommitted work
              # survives even after the pre-rollback snapshots are pruned - losing this repo to a
              # reboot is what prompted it.
              "Repositories"

              ".local/share/fish" # shell history
              ".local/state/nix" # per-user nix profile (incl. home-manager generations)
              ".local/state/home-manager" # hm gcroots / news-read state
              ".local/state/wireplumber" # per-device audio volume/routing
              ".local/share/direnv" # direnv allow-list
              ".local/share/nix" # trusted-settings.json
              ".config/noctalia" # Noctalia GUI-mutable settings + custom palettes
              ".config/discord"
              ".claude" # Claude Code: project memory, history, todos
              ".config/zen" # zen-browser profile (moved off ~/.zen via MOZ_LEGACY_PROFILES="")
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

        # @home is recreated from an empty root-owned @home-blank every boot. preservation only
        # owns the persistent side (/persist/home/oscar); the volatile /home/oscar ends up root:root
        # when systemd-tmpfiles auto-creates it as the parent of a persisted subdir, so home-manager
        # (running as oscar) can't write to it. Create it - and ~/.cache, which isn't a parent of
        # anything persisted - explicitly, owned by oscar. Shorter paths are processed first, so
        # /home/oscar gets the right owner before its children.
        tmpfiles.settings.preservation =
          let
            oscarDir = mode: {
              d = {
                inherit mode;
                group = "users";
                user = "oscar";
              };
            };
          in
          {
            "/home/oscar" = oscarDir "0700";
            "/home/oscar/.cache" = oscarDir "0700";
          };
      };
    };
}
