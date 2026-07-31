# The `dataset` quirk: any aspect can contribute one to request a ZFS dataset - declared once,
# consumed both by samba.nix (for the ones flagged `samba = true;`) and, below, by every host that
# includes `my.zfs`, which ensures each contributed dataset actually EXISTS (`zfs create`, if
# missing) and - optionally - is owned by a specific user/group, before anything that mounts it as
# a container volume gets a chance to race it.
#
# Record shape:
#   name        - (required) dataset name, mounted at `<pool>/<name>` (ZFS's own mountpoint
#                 inheritance - nothing here overrides `mountpoint`, so this assumes the pool's own
#                 mountpoint is `/<pool>`, true for every pool in this repo so far).
#   pool        - (required) the ZFS pool this dataset belongs to.
#   samba       - (optional, bool) share it via Samba - see samba.nix.
#   guestAccess - (optional, bool) allow guest (unauthenticated) Samba access - see samba.nix.
#   user/group  - (optional) chown the dataset's root directory to this user:group once created -
#                 for a dataset a container-based service needs to write into as some UID/GID other
#                 than root (e.g. a shared library directory two containers both write into). Both
#                 fields must be given together, or neither.
{ lib, ... }: {
  den.quirks.dataset.description = "ZFS datasets required by aspects, optionally shared via Samba and/or owned by a specific user";

  my.zfs = pools: {
    nixos =
      { pkgs, dataset, ... }:
      let
        # Use the default ZFS package for compatibility checking to avoid infinite recursion
        # We can't use config.boot.zfs.package here because it depends on kernelPackages which we're trying to determine
        defaultZfsPackage = pkgs.zfs;
        # One oneshot service per dataset - name matches `zfs-dataset-<pool>-<name>`, which any
        # consumer needing the dataset actually mounted+owned before it starts (e.g. an
        # oci-containers service bind-mounting it) should depend on directly, by that name, via its
        # own `systemd.services."podman-<container>".after/requires` (see bookshelf.nix for the
        # pattern - `dependsOn` on the container itself only accepts OTHER containers, not arbitrary
        # systemd units).
        #
        # This can't be a plain `systemd.tmpfiles.rule`: `systemd-tmpfiles-setup.service` runs
        # `Before = [ "sysinit.target" ]`, but these pools are `boot.zfs.extraPools` (not the root
        # filesystem), imported/mounted by `zfs-import.target`/`zfs-mount.service`, both reached via
        # `zfs.target`'s own `wantedBy = [ "multi-user.target" ]` - long after sysinit.target. A
        # tmpfiles rule would run first, creating (and chowning) a plain directory on the root
        # filesystem that the real mount then silently shadows once it happens - permissions on the
        # actual dataset never change. Ordering this after `zfs-import.target` instead (needed
        # either way, to create a dataset that doesn't exist yet - there's no mount for
        # `RequiresMountsFor` to wait on until AFTER we've created it) sidesteps that entirely.
        ensureDatasetService = d: {
          name = "zfs-dataset-${d.pool}-${d.name}";

          value = {
            after = [ "zfs-import.target" ];
            description = "Ensure ZFS dataset ${d.pool}/${d.name} exists";
            requires = [ "zfs-import.target" ];

            serviceConfig = {
              ExecStart = pkgs.writeShellScript "ensure-zfs-dataset-${d.pool}-${d.name}" (
                ''
                  set -eu
                  ${defaultZfsPackage}/bin/zfs list -H ${lib.escapeShellArg "${d.pool}/${d.name}"} >/dev/null 2>&1 \
                    || ${defaultZfsPackage}/bin/zfs create -p ${lib.escapeShellArg "${d.pool}/${d.name}"}
                ''
                + lib.optionalString (d ? user) ''
                  ${pkgs.coreutils}/bin/chown ${lib.escapeShellArg "${d.user}:${d.group}"} ${lib.escapeShellArg "/${d.pool}/${d.name}"}
                ''
              );

              RemainAfterExit = true;
              Type = "oneshot";
            };
          };
        };
        # Select the latest compatible kernel version
        latestKernelPackage = lib.last (
          lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (builtins.attrValues zfsCompatibleKernelPackages)
        );
        # Find all ZFS-compatible kernel packages
        zfsCompatibleKernelPackages = lib.filterAttrs (
          name: kernelPackages:
          (builtins.match "linux_[0-9]+_[0-9]+" name) != null
          && (builtins.tryEval kernelPackages).success
          && (builtins.tryEval (!kernelPackages.${defaultZfsPackage.kernelModuleAttribute}.meta.broken)).value or false
        ) pkgs.linuxKernel.packages;
      in
      {
        boot = {
          # Use latest ZFS-compatible kernel instead of absolute latest
          # Note: this might jump back and forth as kernels are added or removed
          kernelPackages = latestKernelPackage;
          supportedFilesystems = [ "zfs" ];

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

        systemd.services = lib.listToAttrs (map ensureDatasetService dataset);
      };
  };
}
