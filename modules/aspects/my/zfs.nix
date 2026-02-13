{ lib, ... }:
{
  my.zfs = pools: {
    nixos =
      { config, pkgs, ... }:
      let
        # Find all ZFS-compatible kernel packages
        zfsCompatibleKernelPackages = lib.filterAttrs (
          name: kernelPackages:
          (builtins.match "linux_[0-9]+_[0-9]+" name) != null
          && (builtins.tryEval kernelPackages).success
          && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
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
          kernelPackages = lib.mkForce latestKernelPackage;
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
      };
  };
}
