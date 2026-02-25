# CachyOS Kernel Aspect
#
# This aspect enables the CachyOS kernel with optimizations and patches from https://github.com/CachyOS/kernel-patches
# The kernel is provided by https://github.com/xddxdd/nix-cachyos-kernel with pre-built binaries available via cache.
#
# Features:
# - Latest CachyOS kernel with optimizations and performance patches
# - ZFS support via CachyOS-patched ZFS modules (automatically enabled if ZFS is in use)
# - Binary cache support for faster deployments
#
# Usage:
#   Add to your host's includes:
#     (cachyos-kernel { }) # Uses "latest-lto" variant by default
#     (cachyos-kernel { variant = "server-lto"; }) # Use server-lto variant (for harmony)
#
# Available variants include: latest-lto (default), server, server-lto, bore-lto, hardened-lto, etc. See
# https://github.com/xddxdd/nix-cachyos-kernel for full list of variants.
#
# Note: This aspect uses mkForce to override any other kernel settings (including the standard boot aspect). If you're
#       using ZFS, this will automatically use the CachyOS-patched ZFS module.
#
# After adding this aspect, run: nix run .#write-flake
#
{ inputs, ... }:
{
  # Don't follow any sub-inputs since that'll invalidate the cache
  flake-file.inputs.nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

  my.cachyos-kernel =
    {
      variant ? "latest-lto",
    }:
    {
      nixos =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          nix.settings = {
            extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
            extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
          };

          nixpkgs.overlays = [
            # Use the exact kernel versions as defined in nix-cachyos-kernel repo.
            # Guarantees binary cache availability.
            inputs.nix-cachyos-kernel.overlays.pinned
          ];

          boot = {
            # Use mkForce to override the default kernel (including ZFS aspect if present)
            kernelPackages = lib.mkForce pkgs.cachyosKernels."linuxPackages-cachyos-${variant}";

            # Use the CachyOS-patched ZFS module (no-op if ZFS isn't enabled)
            zfs.package = config.boot.kernelPackages.zfs_cachyos;
          };
        };
    };
}
