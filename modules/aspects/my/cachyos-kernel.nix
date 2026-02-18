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
#   Add to your host's includes: cachyos-kernel
#
# Note: This aspect uses mkForce to override any other kernel settings (including the standard boot aspect).
#       If you're using ZFS, this will automatically use the CachyOS-patched ZFS module.
#
# After adding this aspect, run: nix run .#write-flake
#
{ inputs, ... }:
{
  flake-file.inputs.nix-cachyos-kernel = {
    url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  my.cachyos-kernel.nixos =
    { config, pkgs, lib, ... }:
    {
      nixpkgs.overlays = [
        # Use the exact kernel versions as defined in nix-cachyos-kernel repo.
        # Guarantees binary cache availability.
        inputs.nix-cachyos-kernel.overlays.pinned
      ];

      boot = {
        # Use mkForce to override the default kernel (including ZFS aspect if present)
        kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-latest;

        # If ZFS is enabled, use the CachyOS-patched ZFS module
        zfs.package = lib.mkIf (
          builtins.elem "zfs" config.boot.supportedFilesystems
        ) config.boot.kernelPackages.zfs_cachyos;
      };

      nix.settings = {
        substituters = [
          "https://cache.garnix.io"
          "https://cache.lantian.pub"
        ];
        trusted-public-keys = [
          "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
          "cache.lantian.pub:8ZNQJS+GqwfWJPAe6SLNuZiJvXmyqDn+/d/PnxaXhLg="
        ];
      };
    };
}
