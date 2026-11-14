# rescue-boot - a self-contained NixOS rescue system in the systemd-boot menu.
#
# Adds a "NixOS rescue" entry whose kernel + initrd live on the ESP. The initrd carries its own
# squashfs Nix store (nixpkgs' netboot image), so it runs entirely from RAM and never touches the
# root filesystem - recovery doesn't need install media even when the main btrfs won't mount.
# Wi-Fi works once it's booted (iwd: `iwctl station wlan0 connect <SSID>`); true firmware netboot (PXE/HTTP boot)
# would not, since the firmware network stack is Ethernet-only.
#
# Host-agnostic; the only hardware-specific knob is firmware. The image is trimmed to stay small
# enough to sit on the ESP next to the regular generations: only the linux-firmware paths in
# `firmware` are included (default: Intel Wi-Fi + graphics, which covers every current host), and
# no ZFS. `firmware = null` ships all redistributable firmware instead (much bigger). The build fails
# if the initrd grows past `maxInitrdMiB`, rather than filling the ESP later; hosts with a small ESP
# may also want a lower `boot.loader.systemd-boot.configurationLimit`.
#
# Usage: `(rescue-boot { })`, or e.g. `(rescue-boot { firmware = [ "rtw89" "i915" ]; })` for a
# Realtek Wi-Fi host. Entries are paths/globs relative to linux-firmware's lib/firmware.
#
# Inside the rescue system: `cryptsetup open`, `btrfs`, `mkfs.*`, `nixos-install` and `git` are
# available; root has no password on the console (the netboot installer default).
{ inputs, ... }: {
  my.rescue-boot =
    {
      firmware ? [
        "iwlwifi-*"
        "intel/iwlwifi"
        "i915"
        "xe"
      ],
      maxInitrdMiB ? 400,
    }:
    {
      nixos =
        { pkgs, ... }:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          build = rescue.config.system.build;
          # Fail the build (and CI) instead of overflowing the ESP.
          initrd = pkgs.runCommand "rescue-initrd" { } ''
            size=$(stat -L -c %s ${build.netbootRamdisk}/initrd)
            echo "rescue initrd: $((size / 1048576)) MiB (limit ${toString maxInitrdMiB} MiB)"
            if [ "$size" -gt $((${toString maxInitrdMiB} * 1048576)) ]; then
              echo "rescue initrd is too big for the ESP. Largest store paths in the rescue system:" >&2
              # closureInfo's registration: path, hash, narSize, deriver, ref count, refs...
              awk '
                s == 0 { p = $0; s = 1; next }
                s == 1 { s = 2; next }
                s == 2 { z = $0; s = 3; next }
                s == 3 { s = 4; next }
                s == 4 { n = $0; print z, p; s = n > 0 ? 5 : 0; next }
                s == 5 { if (--n == 0) s = 0 }
              ' ${pkgs.closureInfo { rootPaths = [ build.toplevel ]; }}/registration \
                | sort -n | tail -n 25 | awk '{ printf "%8.1f MiB  %s\n", $1 / 1048576, $2 }' >&2
              exit 1
            fi
            cp ${build.netbootRamdisk}/initrd $out
          '';
          rescue = inputs.nixpkgs.lib.nixosSystem {
            modules = [
              (
                {
                  lib,
                  pkgs,
                  modulesPath,
                  ...
                }:
                {
                  imports = [ (modulesPath + "/installer/netboot/netboot-minimal.nix") ];

                  boot = {
                    # Newest kernel, for the newest hardware (Wi-Fi, graphics).
                    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
                    # Only what a rescue needs; the installer profile adds bcachefs, cifs, f2fs, ntfs,
                    # zfs and more.
                    supportedFilesystems = lib.mkForce [
                      "btrfs"
                      "ext4"
                      "vfat"
                      "xfs"
                    ];
                  };

                  # Size trims - the installer profile otherwise ships a whole build toolchain
                  # (extraDependencies, for offline installs) and docs; a rescue system can fetch
                  # from the binary cache instead.
                  documentation.enable = lib.mkForce false;

                  i18n.supportedLocales = lib.mkForce [
                    "C.UTF-8/UTF-8"
                    "en_US.UTF-8/UTF-8"
                  ];
                  environment.systemPackages = [ pkgs.gitMinimal ];

                  # Only what's needed for networking and a working console (see `firmware` above).
                  hardware = lib.mkIf (firmware != null) {
                    enableAllFirmware = lib.mkForce false;
                    enableRedistributableFirmware = lib.mkForce false;

                    firmware = lib.mkForce [
                      (pkgs.runCommand "rescue-firmware" { } ''
                        mkdir -p $out/lib/firmware
                        cd ${pkgs.linux-firmware}/lib/firmware
                        shopt -s nullglob
                        for f in ${lib.concatStringsSep " " firmware}; do
                          if [ -e "$f" ]; then cp -a --parents "$f" $out/lib/firmware/; fi
                        done
                      '')
                    ];
                  };

                  # iwd rather than NetworkManager (a much smaller closure). Connect with
                  # `iwctl station wlan0 connect <SSID>`; wired Ethernet gets DHCP automatically.
                  networking = {
                    networkmanager.enable = lib.mkForce false;
                    useDHCP = lib.mkForce true;

                    wireless = {
                      enable = lib.mkForce false;

                      iwd = {
                        enable = true;
                        settings.General.EnableNetworkConfiguration = true;
                      };
                    };
                  };

                  nix.settings.experimental-features = [
                    "nix-command"
                    "flakes"
                  ];

                  # From the host's pkgs (the outer `system`), not this module's own `pkgs`, which
                  # is derived from this very option.
                  nixpkgs.hostPlatform = system;
                  system.extraDependencies = lib.mkForce [ ];
                }
              )
            ];
          };
        in
        {
          boot.loader.systemd-boot = {
            extraEntries."rescue.conf" = ''
              title NixOS rescue (runs from RAM)
              sort-key rescue
              linux /efi/rescue/bzImage
              initrd /efi/rescue/initrd
              options init=${build.toplevel}/init ${toString rescue.config.boot.kernelParams}
            '';

            extraFiles = {
              "efi/rescue/bzImage" = "${build.kernel}/${rescue.config.system.boot.loader.kernelFile}";
              "efi/rescue/initrd" = initrd;
            };
          };
        };
    };
}
