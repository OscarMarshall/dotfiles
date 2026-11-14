# rescue-boot - a self-contained NixOS rescue system in the systemd-boot menu.
#
# Adds a "NixOS rescue" entry whose kernel + initrd live on the ESP. The initrd carries its own
# squashfs Nix store (nixpkgs' netboot image), so it runs entirely from RAM and never touches the
# root filesystem - recovery doesn't need install media even when the main btrfs won't mount.
# Wi-Fi works once it's booted (NetworkManager: `nmtui`); true firmware netboot (PXE/HTTP boot)
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
          build = rescue.config.system.build;
          # Fail the build (and CI) instead of overflowing the ESP.
          initrd = pkgs.runCommand "rescue-initrd" { } ''
            size=$(stat -L -c %s ${build.netbootRamdisk}/initrd)
            echo "rescue initrd: $((size / 1048576)) MiB (limit ${toString maxInitrdMiB} MiB)"
            if [ "$size" -gt $((${toString maxInitrdMiB} * 1048576)) ]; then
              echo "rescue initrd is too big for the ESP" >&2
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
                    supportedFilesystems.zfs = lib.mkForce false;
                  };

                  environment.systemPackages = [ pkgs.git ];

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

                  networking = {
                    networkmanager = {
                      enable = true;
                      plugins = lib.mkForce [ ];
                    };

                    wireless.enable = lib.mkForce false;
                  };

                  nix.settings.experimental-features = [
                    "nix-command"
                    "flakes"
                  ];

                  nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
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
