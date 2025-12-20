# NixOS Configuration Modules

This directory contains modular NixOS configuration files organized by functionality.

## Module Overview

- **boot.nix** - Boot loader, kernel modules, and ZFS configuration
- **networking.nix** - Network configuration, hostname, firewall, timezone, and locale settings
- **users.nix** - User account configuration
- **secrets.nix** - Age-encrypted secrets configuration
- **nginx.nix** - Nginx web server and reverse proxy configuration, including ACME/Let's Encrypt
- **media-services.nix** - Media server and *arr stack services (Plex, Radarr, Sonarr, Prowlarr, qBittorrent, etc.)
- **minecraft.nix** - Minecraft server configuration
- **vpn.nix** - VPN namespace configuration for routing services through VPN
- **services.nix** - Other system services (Homepage Dashboard, Samba, ZFS, OpenSSH, etc.)

## Usage

These modules are imported in the main `configuration.nix` file at the root of the repository.

To modify a specific aspect of the configuration:
1. Find the relevant module file
2. Make your changes
3. Rebuild the system with `nixos-rebuild switch`
