# rescue-boot - a self-contained NixOS rescue system in the systemd-boot menu.
#
# Adds a "NixOS rescue" entry whose kernel + initrd live on the ESP. The initrd carries its own
# squashfs Nix store (nixpkgs' netboot module), so it runs entirely from RAM and never touches the
# root filesystem - recovery doesn't need install media even when the main btrfs won't mount.
# Wi-Fi works once it's booted (iwd: `iwctl station wlan0 connect <SSID>`); wired Ethernet gets DHCP
# automatically. True firmware netboot (PXE/HTTP boot) would not work over Wi-Fi, since the
# firmware network stack is Ethernet-only.
#
# Built on the bare netboot module rather than the netboot *installer* profile, which pulls in
# Python, Perl, vim, docs, a build toolchain and a copy of nixpkgs (~600 MiB in total). Only what a
# rescue needs is included: LUKS, btrfs/ext4/vfat tools, partitioning, rsync and
# `nixos-install` (which takes a `--flake github:...` directly, so no git). Root is logged in
# automatically on the console with no password.
#
# Host-agnostic; the only hardware-specific knob is firmware: only the linux-firmware paths in
# `firmware` are included (default: Intel Wi-Fi + graphics, which covers every current host).
# The build fails if the initrd grows past `maxInitrdMiB`, and the switch fails if the copy to
# the ESP comes out incomplete (ESP full), rather than leaving a broken entry. Hosts with a small
# ESP may also want a lower `boot.loader.systemd-boot.configurationLimit`.
#
# Usage: `(rescue-boot { })`, or e.g. `(rescue-boot { firmware = [ "rtw89" "i915" ]; })` for a
# Realtek Wi-Fi host. Entries are paths/globs relative to linux-firmware's lib/firmware.
{ inputs, ... }: {
  my.rescue-boot =
    {
      firmware ? [
        "iwlwifi-*"
        "intel/iwlwifi"
        "i915"
        "xe"
      ],
      maxInitrdMiB ? 512,
    }:
    {
      nixos =
        { config, pkgs, ... }:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          build = rescue.config.system.build;
          bzImage = "${build.kernel}/${rescue.config.system.boot.loader.kernelFile}";
          espRescueDir = "${config.boot.loader.efi.efiSysMountPoint}/efi/rescue";
          # Fail the build (and CI) instead of overflowing the ESP.
          initrd = pkgs.runCommand "rescue-initrd" { } ''
            size=$(stat -L -c %s ${build.netbootRamdisk}/initrd)
            echo "rescue initrd: $((size / 1048576)) MiB (limit ${toString maxInitrdMiB} MiB)"
            if [ "$size" -gt $((${toString maxInitrdMiB} * 1048576)) ]; then
              echo "rescue initrd is too big for the ESP. Largest paths in it:" >&2
              echo "  nix path-info -rsSh ${build.toplevel} | sort -k2 -h | tail -n 25" >&2
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
                  imports = [
                    (modulesPath + "/installer/netboot/netboot.nix")
                    (modulesPath + "/profiles/minimal.nix")
                  ];

                  boot = {
                    # Newest kernel, for the newest hardware (Wi-Fi, graphics).
                    kernelPackages = pkgs.linuxPackages_latest;

                    supportedFilesystems = [
                      "btrfs"
                      "ext4"
                      "vfat"
                    ];
                  };

                  documentation = {
                    enable = false;
                    man.enable = false;
                  };

                  environment.systemPackages = with pkgs; [
                    cryptsetup
                    dosfstools
                    efibootmgr
                    gptfdisk
                    nixos-install-tools
                    pciutils
                    rsync
                    usbutils
                  ];

                  # Only what's needed for networking and a working console (see `firmware` above).
                  hardware = {
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

                  i18n.supportedLocales = [
                    "C.UTF-8/UTF-8"
                    "en_US.UTF-8/UTF-8"
                  ];

                  networking = {
                    hostName = "rescue";
                    useDHCP = true;

                    wireless.iwd = {
                      enable = true;
                      settings.General.EnableNetworkConfiguration = true;
                    };
                  };

                  nix.settings.experimental-features = [
                    "nix-command"
                    "flakes"
                  ];

                  nixpkgs = {
                    # Don't pin a ~200 MiB copy of the nixpkgs source into the image.
                    flake = {
                      setFlakeRegistry = false;
                      setNixPath = false;
                    };

                    # From the host's pkgs (the outer `system`), not this module's own `pkgs`, which
                    # is derived from this very option.
                    hostPlatform = system;
                  };

                  services = {
                    getty.autologinUser = "root";
                    # Replaces the Perl user/group activation script.
                    userborn.enable = true;
                  };

                  system = {
                    # The default NixOS tools pull in Python (nixos-rebuild-ng) among others;
                    # nixos-install-tools above provides what a rescue needs.
                    disableInstallerTools = true;
                    stateVersion = lib.trivial.release;
                  };

                  users.users.root.initialHashedPassword = "";
                }
              )
            ];
          };
        in
        {
          boot.loader.systemd-boot = {
            # nixpkgs' copy-extra-files doesn't stop on errors, so an ESP that fills up mid-copy
            # would leave a truncated image behind a "successful" switch. Check the copies.
            extraInstallCommands = ''
              for f in ${bzImage}:bzImage ${initrd}:initrd; do
                if ! ${pkgs.diffutils}/bin/cmp -s "''${f%%:*}" "${espRescueDir}/''${f##*:}"; then
                  echo "rescue-boot: copying ''${f##*:} to the ESP failed (ESP full?)" >&2
                  exit 1
                fi
              done
            '';

            extraEntries."rescue.conf" = ''
              title NixOS rescue (runs from RAM)
              sort-key rescue
              linux /efi/rescue/bzImage
              initrd /efi/rescue/initrd
              options init=${build.toplevel}/init ${toString rescue.config.boot.kernelParams}
            '';

            extraFiles = {
              "efi/rescue/bzImage" = bzImage;
              "efi/rescue/initrd" = initrd;
            };
          };
        };
    };
}
