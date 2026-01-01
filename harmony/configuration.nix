{inputs, ...}: {
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./hardware-configuration.nix
    ../cachix.nix
    ../modules/apcupsd.nix
    ../modules/autobrr.nix
    ../modules/boot.nix
    ../modules/cross-seed.nix
    ../modules/glances.nix
    ../modules/gluetun.nix
    ../modules/homepage.nix
    ../modules/minecraft.nix
    ../modules/networking.nix
    ../modules/nginx.nix
    ../modules/nixpkgs.nix
    ../modules/openssh.nix
    ../modules/plex.nix
    ../modules/profilarr.nix
    ../modules/prowlarr.nix
    ../modules/qbittorrent.nix
    ../modules/radarr.nix
    ../modules/samba.nix
    ../modules/secrets.nix
    ../modules/sonarr.nix
    ../modules/ssh.nix
    ../modules/system.nix
    ../modules/unpackerr.nix
    ../modules/users.nix
    ../modules/zfs.nix
  ];

  # Set hostname for this system
  networking.hostName = "harmony";
}
