# disko layout for tensoon (Framework 13, WD_BLACK SN7100 2TB).
#
#   GPT
#   ├─ part1  ESP    1 GiB   vfat            → /boot
#   ├─ part2  swap   34 GiB  LUKS → swap     → hibernate resume device (32 GiB RAM + headroom)
#   └─ part3  root   rest    LUKS → btrfs    → subvolumes @nix @persist @home
#
# `/` is tmpfs (nothing on it survives a reboot). `/home` is a btrfs subvolume that the
# rollback-home initrd service (my.preservation) resets to the empty `@home-blank` snapshot on
# every boot, after taking a read-only snapshot of the outgoing `@home` under `@home-snapshots/`.
# Anything that must persist is listed in my.preservation and bind-mounted from `/persist`.
#
# Both LUKS containers take the same passphrase at install (via /tmp/luks.key) so systemd's
# password agent unlocks both from one prompt at boot. Enroll the YubiKey afterwards with
# `systemd-cryptenroll --fido2-device=auto <part2>` / `<part3>`; the `fido2-device=auto` crypttab
# option below is what makes stage-1 systemd-cryptsetup actually offer it (and drags libfido2 +
# USB-HID into the initrd). At the boot prompt: insert the key, touch it when it blinks; no key
# -> the passphrase prompt still works.
{
  den.aspects.tensoon.nixos = {
    disko.devices = {
      disk.main = {
        content = {
          partitions = {
            ESP = {
              content = {
                format = "vfat";
                mountOptions = [ "umask=0077" ];
                mountpoint = "/boot";
                type = "filesystem";
              };

              size = "1G";
              type = "EF00";
            };

            root = {
              content = {
                content = {
                  extraArgs = [ "-f" ];

                  subvolumes = {
                    "@home" = {
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                      ];

                      mountpoint = "/home";
                    };

                    "@nix" = {
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                      ];

                      mountpoint = "/nix";
                    };

                    "@persist" = {
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                      ];

                      mountpoint = "/persist";
                    };
                  };

                  type = "btrfs";
                };

                name = "cryptroot";
                passwordFile = "/tmp/luks.key";

                settings = {
                  allowDiscards = true;
                  crypttabExtraOpts = [ "fido2-device=auto" ]; # offer the enrolled YubiKey at the boot prompt
                };

                type = "luks";
              };

              size = "100%";
            };

            swap = {
              content = {
                content = {
                  resumeDevice = true;
                  type = "swap";
                };

                name = "cryptswap";
                passwordFile = "/tmp/luks.key";

                settings = {
                  allowDiscards = true;
                  crypttabExtraOpts = [ "fido2-device=auto" ]; # offer the enrolled YubiKey at the boot prompt
                };

                type = "luks";
              };

              size = "34G";
            };
          };

          type = "gpt";
        };

        # VERIFY on the machine before running disko: `readlink -f` this must resolve to
        # /dev/nvme0n1 (the whole namespace) - not /dev/nvme0 (controller) and not a partition.
        # (Model prefix is WD_BLACK - Western Digital; the serial still needs checking on the box.)
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_2TB_2548EQ400207_1";
        type = "disk";
      };

      nodev."/" = {
        fsType = "tmpfs";

        mountOptions = [
          "size=2G"
          "mode=755"
        ];
      };
    };

    # Needed in the initrd: /nix for the store, /persist for preservation's `inInitrd` mounts and
    # the rollback-home service.
    fileSystems = {
      "/nix".neededForBoot = true;
      "/persist".neededForBoot = true;
    };
  };
}
