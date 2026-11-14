# rescue-boot - a self-contained NixOS rescue system in the systemd-boot menu.
#
# Adds a "NixOS rescue" entry whose kernel + initrd live on the ESP. The initrd carries its own
# squashfs Nix store (nixpkgs' netboot image), so it runs entirely from RAM and never touches the
# root filesystem - recovery doesn't need install media even when the main btrfs won't mount.
# Wi-Fi works once it's booted (NetworkManager: `nmtui`); true firmware netboot (PXE/HTTP boot)
# would not, since the firmware network stack is Ethernet-only.
#
# The image is trimmed to stay small enough to sit on a 1 GiB ESP next to the regular
# generations: Intel Wi-Fi + graphics firmware only (instead of all of linux-firmware), no ZFS.
# The build fails if the initrd grows past `maxInitrdMiB`, rather than filling the ESP later.
#
# Inside the rescue system: `cryptsetup open`, `btrfs`, `mkfs.*`, `nixos-install` and `git` are
# available; root has no password on the console (the netboot installer default).
{ inputs, ... }: {
  my.rescue-boot =
    {
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
                    # Newest kernel for current Framework hardware (Wi-Fi, graphics).
                    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
                    supportedFilesystems.zfs = lib.mkForce false;
                  };

                  environment.systemPackages = [ pkgs.git ];

                  hardware = {
                    enableAllFirmware = lib.mkForce false;
                    enableRedistributableFirmware = lib.mkForce false;

                    # Only what's needed for networking and a working console.
                    firmware = lib.mkForce [
                      (pkgs.runCommand "rescue-firmware" { } ''
                        mkdir -p $out/lib/firmware/intel
                        cd ${pkgs.linux-firmware}/lib/firmware
                        shopt -s nullglob
                        cp -a iwlwifi-* i915 xe $out/lib/firmware/
                        if [ -e intel/iwlwifi ]; then cp -a intel/iwlwifi $out/lib/firmware/intel/; fi
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
