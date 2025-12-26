# Module Organization

This document describes the organization of the NixOS configuration modules.

## Overview

The configuration has been organized into focused, single-purpose modules in the `modules/` directory. Each module handles a specific domain of the system configuration.

## Module Descriptions

### Core System Modules

#### `system.nix`
Contains core system settings including:
- Auto-upgrade configuration
- Nix garbage collection
- Timezone and locale settings
- ACME/Let's Encrypt configuration
- System state version

#### `boot.nix`
Boot-related configuration:
- Systemd-boot configuration
- ZFS support and pool mounting
- Kernel modules

#### `networking.nix`
Network configuration:
- Hostname and host ID
- NetworkManager
- Firewall rules

### User and Package Management

#### `users.nix`
User accounts and basic system packages:
- User definitions (oscar, qbittorrent, radarr, sonarr)
- SSH keys
- Default shell configuration
- Essential system packages

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
- ZFS automation (scrub, snapshot, trim)

#### `containers.nix`
OCI/Docker container definitions:
- gluetun (VPN with port forwarding)
- qBittorrent (torrent client)
- profilarr (profile manager for *arr apps)
- unpackerr (automatic archive extraction)

#### `media-services.nix`
Media server and automation services:
- Plex Media Server
- Radarr (movie automation)
- Sonarr (TV show automation)
- Prowlarr (indexer manager)
- autobrr (torrent automation)
- cross-seed (cross-seeding automation)
- flaresolverr (Cloudflare bypass)
- homepage-dashboard (unified dashboard)

#### `minecraft.nix`
Minecraft server configurations:
- Multiple server instances
- Fabric and NeoForge servers
- Mod management
- Server properties and RCON configuration

#### `nginx.nix`
Reverse proxy and web server:
- SSL/TLS configuration
- Security headers
- Virtual host definitions
- Reverse proxy rules for all services

#### `samba.nix`
File sharing configuration:
- Share definitions for media directories
- Access permissions
- Windows discovery (samba-wsdd)

#### `secrets.nix`
Agenix secret definitions:
- API keys
- VPN credentials
- Service authentication

## Adding New Configuration

### Adding a New Service

1. Determine which module best fits the service:
   - Media-related? → `media-services.nix`
   - Container? → `containers.nix`
   - System service? → `services.nix`
   - Needs its own module? → Create a new file in `modules/`

2. If creating a new module:
   - Create `modules/new-module.nix`
   - Add appropriate function signature (e.g., `{config, pkgs, ...}:`)
   - Add the module to `configuration.nix` imports

3. Add nginx reverse proxy entry in `nginx.nix` if the service has a web interface

4. Add secrets to `secrets.nix` if needed

### Module Dependencies

Modules can reference configuration from other modules through the `config` parameter:
- `config.age.secrets.<name>.path` - Access secret paths
- `config.services.<service>.settings` - Access service configuration
- `config.users.users.<user>.uid` - Access user IDs
- `config.time.timeZone` - Access system timezone

### Best Practices

1. **Single Responsibility**: Each module should handle one domain
2. **Minimal Coupling**: Avoid tight coupling between modules
3. **Clear Naming**: Use descriptive names for modules and options
4. **Documentation**: Add comments for complex configurations
5. **Consistency**: Follow the existing patterns in other modules

## Module Template

```nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Service or configuration block
  services.myservice = {
    enable = true;
    # ... configuration options
  };

  # Additional related configuration
  # ...
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
- Consider moving conflicting options to a single module

### Secret Path Errors
Secret file paths in `modules/secrets.nix` must be relative to the modules directory:
- Use `../secrets/filename.age` format
- Ensure secret files exist in the `secrets/` directory
