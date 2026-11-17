# preservation - declarative persistent state on top of an ephemeral root.
#
# On tensoon `/` is tmpfs and `/home` is a btrfs subvolume reset to an empty snapshot on every
# boot (see rollback-home below and modules/aspects/hosts/tensoon/disk.nix). Everything that must
# survive a reboot is bind-mounted (or symlinked) from `/persist`. Nothing is listed here: each
# aspect declares its own paths via the `preserve` quirk (modules/aspects/my/preserve.nix), merged
# in below.
{ inputs, ... }: {
  # preservation's flake takes no inputs (the module uses the consumer's pkgs), so there is no
  # nixpkgs to make follow.
  flake-file.inputs.preservation.url = "github:nix-community/preservation";

  my.preservation.nixos =
    {
      config,
      lib,
      pkgs,
      preserve,
      ...
    }:
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
      imports = [
        inputs.preservation.nixosModules.default

        # Fold in every `preserve` quirk contribution (modules/aspects/my/preserve.nix): system
        # paths from host-scoped aspects land here directly, per-user home paths from
        # homeManager aspects arrive via the `expose-preserve` pipe policy. Each entry is
        # already a `preserveAt."/persist"` fragment, so a bare mkMerge is the whole consumer.
        # `mkMerge [ ]` (no producers) is a no-op, so this stays inert until an aspect opts in.
        { preservation.preserveAt."/persist" = lib.mkMerge preserve; }
      ];

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
        initrdBin = [
          pkgs.btrfs-progs
          pkgs.coreutils
        ];

        # Reset the @home subvolume to the pristine @home-blank snapshot before /home is mounted.
        # @home-blank is created once during install (see the plan's walkthrough).
        services.rollback-home = {
          description = "Reset /home to a pristine btrfs snapshot";
          wantedBy = [ "initrd.target" ];

          # Must wait for the hibernation-resume attempt. If a hibernation image exists, the btrfs
          # filesystem is still "mounted" by the frozen kernel in that image; writing to it here
          # (snapshot/delete/recreate @home) and then resuming leaves the resumed kernel with stale
          # in-memory metadata, which corrupts the filesystem (transid errors, unmountable root).
          # DefaultDependencies=no drops the implicit `After=local-fs-pre.target` that orders real
          # mounts after systemd-hibernate-resume.service, so restore it explicitly.
          after = [
            "local-fs-pre.target"
            "systemd-cryptsetup@cryptroot.service"
            "systemd-hibernate-resume.service"
          ];

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
            # ~/Projects would have been saved). Non-recursive: contents of any nested subvolume
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

      preservation.enable = true;

      systemd = {
        # /etc/machine-id is bind-mounted, so the commit service (which expects to persist a tmpfs
        # machine-id) has nothing to do and would fail.
        suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

        # @home is recreated from an empty root-owned @home-blank every boot. preservation only
        # owns the persistent side (/persist/home/<user>); the volatile home ends up root:root when
        # systemd-tmpfiles auto-creates it as the parent of a persisted subdir, so home-manager
        # (running as the user) can't write to it. Create every normal user's home - and its
        # ~/.cache, which isn't a parent of anything persisted - explicitly, owned by that user.
        # Shorter paths are processed first, so the home gets the right owner before its children.
        tmpfiles.settings.preservation = lib.concatMapAttrs (
          _: u:
          let
            userDir.d = {
              inherit (u) group;
              mode = "0700";
              user = u.name;
            };
          in
          {
            ${u.home} = userDir;
            "${u.home}/.cache" = userDir;
          }
        ) (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
      };
    };
}
