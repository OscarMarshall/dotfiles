{inputs, ...}: {
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./hardware-configuration.nix
    ./cachix.nix
    ./modules/boot.nix
    ./modules/gluetun.nix
    ./modules/homepage.nix
    ./modules/media-services.nix
    ./modules/minecraft.nix
    ./modules/networking.nix
    ./modules/nginx.nix
    ./modules/nixpkgs.nix
    ./modules/profilarr.nix
    ./modules/qbittorrent.nix
    ./modules/samba.nix
    ./modules/secrets.nix
    ./modules/services.nix
    ./modules/system.nix
    ./modules/unpackerr.nix
    ./modules/users.nix
    ./modules/zfs.nix
  ];
}
