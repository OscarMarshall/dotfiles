# Module Organization

This document describes the organization of the NixOS configuration modules.

## Overview

The configuration has been organized into focused, single-purpose modules in the `modules/` directory. Each module handles a specific service or system component, with related configuration co-located together.

## Module Descriptions

### Core System Modules

#### `system.nix`

Contains core system settings including:

- Auto-upgrade configuration
- Nix garbage collection
- Timezone and locale settings
- System programs (tmux, zsh)
- System packages
- System state version

#### `boot.nix`

Boot-related configuration:

- Systemd-boot configuration
- EFI variables
- Kernel modules

#### `zfs.nix`

ZFS filesystem configuration:

- ZFS support and pool mounting
- ZFS services (autoScrub, autoSnapshot, trim)

#### `networking.nix`

Network configuration:

- Hostname and host ID
- NetworkManager
- Firewall rules

### User and Package Management

#### `users.nix`

User account definitions:

- User definitions (oscar)
- SSH keys
- Default shell configuration
- User-specific packages

#### `nixpkgs.nix`

Nixpkgs configuration:

- Unfree package permissions
- Overlays (nix-minecraft)

### Service Modules

#### `services.nix`

Miscellaneous system services:

- apcupsd (UPS monitoring)
- glances (system monitoring)
- openssh

### Container Modules

Each container service has its own dedicated module for easier management:

#### `gluetun.nix`

VPN container with port forwarding:

- Proton VPN configuration
- Port forwarding for qBittorrent

#### `qbittorrent.nix`

qBittorrent torrent client:

- Container configuration
- Service user and group
- Nginx reverse proxy configuration
- Group memberships for radarr/sonarr access

#### `profilarr.nix`

Profilarr profile manager:

- Container configuration
- Nginx reverse proxy configuration

#### `unpackerr.nix`

Automatic archive extraction:

- Container configuration
- Integration with radarr/sonarr

### Media Services

Each media service has its own module with co-located nginx configuration:

#### `plex.nix`

Plex Media Server:

- Service configuration
- Firewall rules
- Nginx reverse proxy configuration

#### `radarr.nix`

Movie automation:

- Service configuration
- Nginx reverse proxy configuration

#### `sonarr.nix`

TV show automation:

- Service configuration
- Nginx reverse proxy configuration

#### `prowlarr.nix`

Indexer manager:

- Service configuration for Prowlarr
- Flaresolverr service (co-located in same module for Cloudflare bypass)
- Nginx reverse proxy configuration

#### `autobrr.nix`

Torrent automation:

- Service configuration
- Secret file reference
- Nginx reverse proxy configuration

#### `cross-seed.nix`

Cross-seeding automation:

- Service configuration
- Integration with qBittorrent user/group

### Additional Services

#### `homepage.nix`

Homepage dashboard:

- Service configuration with widgets and bookmarks
- Nginx reverse proxy configuration

#### `minecraft.nix`

Minecraft server configurations:

- Multiple server instances
- Fabric and NeoForge servers
- Mod management
- Server properties and RCON configuration

#### `nginx.nix`

Base nginx configuration:

- SSL/TLS settings
- Security headers
- ACME/Let's Encrypt configuration
- Recommended settings

Note: Virtual host definitions are co-located in their respective service modules.

#### `samba.nix`

File sharing configuration:

- Share definitions for media directories
- Access permissions
- Windows discovery (samba-wsdd)

#### `secrets.nix`

Agenix secret definitions:

- API keys
- VPN credentials
- Service authentication tokens

## Adding New Configuration

### Adding a New Service

1. Create a new module file in `modules/`:
   - Create `modules/new-service.nix`
   - Add appropriate function signature (e.g., `{config, pkgs, ...}:`)
   - Define the service configuration
   - Add nginx reverse proxy configuration if the service has a web interface
   - Add any required users or groups
   - Reference secrets from `config.age.secrets.<name>.path` if needed

2. Add the module to `configuration.nix` imports (in alphabetical order)

3. Add secrets to `secrets.nix` if needed

### Module Dependencies

Modules can reference configuration from other modules through the `config` parameter:

- `config.age.secrets.<name>.path` - Access secret paths
- `config.services.<service>.settings` - Access service configuration
- `config.users.users.<user>.uid` - Access user IDs
- `config.time.timeZone` - Access system timezone

### Best Practices

1. **Single Responsibility**: Each module should handle one service or component
2. **Co-location**: Keep related configuration together (service, nginx config, users)
3. **Minimal Coupling**: Avoid tight coupling between modules
4. **Clear Naming**: Use descriptive names for modules matching service names
5. **Documentation**: Add comments for complex configurations
6. **Consistency**: Follow the existing patterns in other modules

## Module Template

```nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Service configuration
  services.myservice = {
    enable = true;
    # ... configuration options
  };

  # Nginx reverse proxy (if service has web interface)
  services.nginx.virtualHosts."myservice.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:8080/"; # Replace with actual port
  };

  # Users/groups (if needed)
  users.users.myservice = {
    isSystemUser = true;
    group = "myservice";
  };
  users.groups.myservice = {};
}
```

## Validation

Before deploying changes:

1. Check syntax: `nix flake check`
2. Build configuration: `nixos-rebuild build --flake .#harmony`
3. Test configuration: `nixos-rebuild test --flake .#harmony`
4. Deploy: `nixos-rebuild switch --flake .#harmony`

## Troubleshooting

### Import Errors

If you get "file not found" errors, check that:

- The module file exists in `modules/`
- The import path in `configuration.nix` is correct
- The module has proper function signature

### Configuration Conflicts

If options conflict between modules:

- Check for duplicate option definitions
- Use `lib.mkForce` or `lib.mkOverride` to resolve conflicts
- Consider if the configuration truly belongs in a single module

### Secret Path Errors

Secret file paths in `modules/secrets.nix` must be relative to the modules directory:

- Use `../secrets/filename.age` format
- Ensure secret files exist in the `secrets/` directory
