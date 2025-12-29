# Repository Overview

This is a personal NixOS configuration repository for a home server named "harmony". It manages system configuration, services, and user environment using NixOS flakes and Home Manager.

## Repository Structure

- **`flake.nix`**: Main flake configuration defining inputs (nixpkgs, agenix, home-manager, nix-minecraft) and the NixOS system configuration
- **`configuration.nix`**: Top-level configuration that imports all modules (22 lines, imports only)
- **`hardware-configuration.nix`**: Hardware-specific configuration (auto-generated)
- **`home.nix`**: Home Manager configuration for user "oscar" (shell, editor, git, etc.)
- **`cachix.nix`**: Binary cache configuration
- **`modules/`**: Modular configuration organized by service/component (22 modules):
  - `autobrr.nix`: Autobrr service and nginx config
  - `boot.nix`: Boot loader configuration
  - `cross-seed.nix`: Cross-seed service
  - `gluetun.nix`: VPN container
  - `homepage.nix`: Homepage dashboard and nginx config
  - `minecraft.nix`: Minecraft server configurations
  - `networking.nix`: Network settings and firewall rules
  - `nginx.nix`: Base nginx settings and ACME configuration
  - `nixpkgs.nix`: Nixpkgs overlays and package settings
  - `plex.nix`: Plex service and nginx config
  - `profilarr.nix`: Profilarr container and nginx config
  - `prowlarr.nix`: Prowlarr and Flaresolverr services with nginx config
  - `qbittorrent.nix`: qBittorrent container, user/group, and nginx config
  - `radarr.nix`: Radarr service and nginx config
  - `samba.nix`: File sharing configuration
  - `secrets.nix`: Agenix secret definitions
  - `services.nix`: Miscellaneous system services (apcupsd, glances, openssh)
  - `sonarr.nix`: Sonarr service and nginx config
  - `system.nix`: Core system settings, programs, and system packages
  - `unpackerr.nix`: Unpackerr container
  - `users.nix`: User account definitions
  - `zfs.nix`: ZFS filesystem and services configuration
- **`secrets/`**: Directory containing agenix-encrypted secrets (`.age` files) - DO NOT modify or expose these files
- **`secrets/secrets.nix`**: Public keys for agenix encryption
- **`docs/MODULE-ORGANIZATION.md`**: Detailed documentation on module structure and best practices

## Key Technologies

- **NixOS**: Declarative Linux distribution that allows reproducible system configurations
- **Nix Flakes**: Modern Nix package and configuration management with lockfile-based dependency pinning
- **Home Manager**: Manages user-specific configuration (dotfiles, packages, shell, etc.) declaratively
- **agenix**: Secret management using age encryption to securely store sensitive data in the repository
- **Docker/OCI containers**: Several services run in containers for isolation and ease of management (gluetun, qBittorrent, etc.)

## Important Services

The server runs multiple services including:
- **Media Stack**: Plex, Radarr, Sonarr, Prowlarr, qBittorrent (via VPN)
- **VPN**: gluetun container providing VPN with port forwarding
- **Minecraft**: Multiple servers via nix-minecraft
- **Reverse Proxy**: nginx with Let's Encrypt SSL certificates
- **Monitoring**: homepage-dashboard, glances
- **File Sharing**: Samba shares
- **Storage**: ZFS pool named "metalminds"

## Building and Deploying

This is a NixOS system configuration, not a traditional software project. Changes are applied by:

1. **Testing configuration**: Use `nixos-rebuild test` to test changes without modifying boot configuration
2. **Building configuration**: Use `nixos-rebuild build` to build the configuration
3. **Switching configuration**: Use `nixos-rebuild switch` to apply and activate changes
4. **Updating flake inputs**: Use `nix flake update` to update dependencies

Note: These commands typically require root/sudo access and are run on the target system, not in a CI environment.

## Validation

- **Syntax check**: `nix flake check` validates flake syntax
- **Evaluation check**: `nix flake show` displays the flake outputs
- **Build check**: `nixos-rebuild build --flake .#harmony` builds the configuration without applying it

## Best Practices

1. **Secrets Management**: All secrets are encrypted using agenix. Never commit plaintext secrets or modify `.age` files directly
2. **State Version**: Never change `system.stateVersion` or `home.stateVersion` unless you understand the implications (see comments in files)
3. **Declarative Configuration**: All system configuration should be in Nix files, avoid imperative changes
4. **Flake Lock**: `flake.lock` pins dependency versions; update explicitly with `nix flake update`
5. **Service Configuration**: Most services are configured declaratively via NixOS options in their respective module files
6. **Module Organization**: Each service has its own module with co-located nginx configs, users, and dependencies
7. **User Groups**: User "oscar" has specific group memberships for service access (minecraft, qbittorrent, radarr, sonarr, wheel)

## Security Considerations

- SSL/TLS is handled by nginx with Let's Encrypt certificates (ACME)
- Secrets are managed via agenix with age encryption
- VPN (gluetun) protects qBittorrent traffic
- Firewall is enabled with specific port allowances
- OpenSSH is enabled for remote access

## Common Patterns

- Services are typically enabled with `services.<name>.enable = true` in their respective module
- Each service module includes its nginx virtual host configuration where applicable
- Docker containers are defined in individual container modules (gluetun.nix, qbittorrent.nix, profilarr.nix, unpackerr.nix)
- nginx virtual hosts are co-located with their services, not centralized in nginx.nix
- File paths use `/metalminds/` prefix for the ZFS storage pool
- Secret paths in modules use relative paths: `../secrets/filename.age`

## Module Organization

The configuration is organized into 22 focused modules:

- **Core System**: boot.nix, networking.nix, system.nix, users.nix, zfs.nix
- **Infrastructure**: nginx.nix, nixpkgs.nix, secrets.nix, services.nix
- **Containers**: gluetun.nix, qbittorrent.nix, profilarr.nix, unpackerr.nix
- **Media Services**: autobrr.nix, cross-seed.nix, plex.nix, prowlarr.nix, radarr.nix, sonarr.nix
- **Other Services**: homepage.nix, minecraft.nix, samba.nix

Each module is self-contained with related configuration co-located together. See `docs/MODULE-ORGANIZATION.md` for detailed documentation.

## Limitations for AI Agents

- Cannot execute `nixos-rebuild` commands (requires target system access)
- Cannot test actual service functionality (no runtime environment)
- Cannot decrypt or modify agenix secrets
- Cannot access the actual "harmony" server
- Focus on configuration file correctness and NixOS best practices
