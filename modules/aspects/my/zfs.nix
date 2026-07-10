{ lib, ... }: {
  den.quirks.dataset.description = "ZFS datasets required by aspects, optionally shared via Samba";

  my.zfs = pools: {
    nixos =
      { dataset, pkgs, ... }:
      let
        # Use the default ZFS package for compatibility checking to avoid infinite recursion
        # We can't use config.boot.zfs.package here because it depends on kernelPackages which we're trying to determine
        defaultZfsPackage = pkgs.zfs;

        # Find all ZFS-compatible kernel packages
        zfsCompatibleKernelPackages = lib.filterAttrs (
          name: kernelPackages:
          (builtins.match "linux_[0-9]+_[0-9]+" name) != null
          && (builtins.tryEval kernelPackages).success
          && (builtins.tryEval (!kernelPackages.${defaultZfsPackage.kernelModuleAttribute}.meta.broken)).value or false
        ) pkgs.linuxKernel.packages;

        # Select the latest compatible kernel version
        latestKernelPackage = lib.last (
          lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (builtins.attrValues zfsCompatibleKernelPackages)
        );
      in
      {
        boot = {
          supportedFilesystems = [ "zfs" ];
          # Use latest ZFS-compatible kernel instead of absolute latest
          # Note: this might jump back and forth as kernels are added or removed
          kernelPackages = latestKernelPackage;
          zfs = {
            extraPools = pools;
            forceImportRoot = false;
          };
        };

        services.zfs = {
          autoScrub.enable = true;
          autoSnapshot.enable = true;
          trim.enable = true;
        };

        # New child datasets inherit their parent pool's properties, so `options` should only be used to
        # deviate from those, not to restate them. As of 2026-07-10, metalminds (harmony's data pool) has
        # compression=on (lz4), atime=off, and recordsize=128K - all sane defaults for most workloads.
        #
        # Datasets are only ever created if missing, never renamed or reconfigured - changing a
        # dataset's name, options, or other properties later leaves the old dataset behind untouched.
        system.activationScripts.zfsDatasets = lib.concatMapStrings (
          d:
          let
            name = "${d.pool}/${d.name}";
            mountpoint = "/${name}";
            options = lib.concatStrings (
              lib.mapAttrsToList (property: value: " -o ${lib.escapeShellArg "${property}=${value}"}") (d.options or { })
            );
          in
          ''
            if ! ${pkgs.zfs}/bin/zfs list -H -o name ${lib.escapeShellArg name} >/dev/null 2>&1; then
              if [ -d ${lib.escapeShellArg mountpoint} ] && [ -n "$(ls -A ${lib.escapeShellArg mountpoint})" ]; then
                echo "zfs dataset ${lib.escapeShellArg name} is missing, but ${lib.escapeShellArg mountpoint} already exists and is non-empty - move its contents aside, then re-run the activation" >&2
                exit 1
              fi
              ${pkgs.zfs}/bin/zfs create -p${options} ${lib.escapeShellArg name}
            fi
          ''
        ) dataset;
      };
  };
}
