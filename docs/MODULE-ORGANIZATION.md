# Module Organization

This document describes the organization of the NixOS configuration modules following the [Dendritic Design Pattern](https://github.com/Doc-Steve/dendritic-design-with-flake-parts).

## Overview

The configuration uses the **Dendritic Design Pattern** with [flake-parts](https://flake.parts) to organize code into reusable feature modules. Each module is self-contained and can define configuration for multiple contexts (NixOS, Home Manager, etc.).

### Key Principles

1. **Feature-based organization**: Each module represents a feature (service, app, or configuration aspect)
2. **Bottom-up composition**: Features define their requirements; hosts import features they need
3. **Co-location**: All configuration for a feature lives in one place (service config, nginx vhost, firewall rules, etc.)
4. **Reusability**: Features can be easily shared between hosts and imported by other features

## Directory Structure

```
modules/
├── lib/              # Helper functions and tools
├── system/           # Core system configuration
├── services/         # Service modules (one per service)
├── programs/         # Desktop programs and applications
├── users/            # User configurations
└── hosts/            # Host-specific configurations
```

## Module Pattern

Each feature module follows this structure:

```nix
{inputs, ...}: {
  flake.modules.nixos.<feature-name> = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # NixOS configuration for this feature
    # Can import other features:
    imports = with inputs.self.modules.nixos; [
      dependency-feature
    ];
    
    # Define services, packages, etc.
    services.myservice.enable = true;
    
    # Co-locate related configuration
    networking.firewall.allowedTCPPorts = [80];
    users.users.myuser.extraGroups = ["myservice"];
  };
  
  # Optional: Home Manager aspect
  flake.modules.homeManager.<feature-name> = {pkgs, ...}: {
    # Home Manager configuration for this feature
  };
}
```

## Module Categories

### Library Modules (`lib/`)

Helper functions and development tools that don't define system configuration directly.

#### `default.nix`
- Provides `mkNixos` helper function for creating NixOS configurations
- Used by host modules to generate nixosConfigurations

#### `dev-tools.nix`
- Pre-commit hooks (alejandra, flake-checker, statix, prettier)
- `nix fmt` formatter
- Development shell with hooks installed

### System Modules (`system/`)

Core system configuration that nearly all hosts need.

#### `agenix.nix`
- Integrates agenix for secret management
- Adds agenix package to system packages

#### `boot.nix`
- Systemd-boot configuration
- Latest kernel package

#### `home-manager.nix`
- Integrates Home Manager into NixOS
- Sets `useGlobalPkgs` and `useUserPackages`

#### `networking.nix`
- Host ID configuration (harmony-specific)
- NetworkManager enablement
- User groups for NetworkManager access

#### `nixpkgs.nix`
- Nixpkgs configuration (allowUnfree)
- Overlays (nix-minecraft)

#### `secrets.nix`
- Defines paths to all agenix secrets
- Keeps secret definitions centralized

#### `system-core.nix`
- System auto-upgrade configuration
- Nix garbage collection
- Experimental features (flakes, nix-command)
- Timezone and locale settings
- Console configuration
- Zsh enablement

#### `zfs.nix`
- ZFS filesystem support
- Latest ZFS-compatible kernel selection
- ZFS pool configuration
- ZFS services (autoScrub, autoSnapshot, trim)

### Service Modules (`services/`)

Each service module is self-contained with all related configuration.

#### Common Pattern
Service modules typically include:
- Service enablement and configuration
- Nginx virtual host (if web-accessible)
- Firewall rules (if needed)
- User/group configuration (if needed)
- Secret file references (via secrets.nix)

#### Infrastructure Services

**`nginx.nix`**
- Base nginx configuration
- ACME/Let's Encrypt setup
- Security headers
- Firewall rules for HTTP/HTTPS

**`ssh.nix`**
- OpenSSH service
- Tmux
- Firewall configuration

**`apcupsd.nix`**
- APC UPS monitoring daemon

**`glances.nix`**
- System monitoring service

**`lm_sensors.nix`**
- Hardware temperature monitoring
- Coretemp kernel module

#### Media Services

**`plex.nix`**
- Plex Media Server
- Nginx reverse proxy
- Firewall rules

**`autobrr.nix`**
- Autobrr automation service
- Nginx reverse proxy
- Secret file integration

**`cross-seed.nix`**
- Cross-seed torrent service
- qBittorrent integration

**`radarr.nix`**
- Radarr movie management
- Nginx reverse proxy

**`sonarr.nix`**
- Sonarr TV show management
- Nginx reverse proxy

**`prowlarr.nix`**
- Prowlarr indexer manager
- Flaresolverr integration
- Nginx reverse proxy

#### Container Services

**`gluetun.nix`**
- VPN container (ProtonVPN)
- WireGuard configuration
- Port forwarding for qBittorrent
- Automatic port update

**`qbittorrent.nix`**
- qBittorrent torrent client container
- Service user and group
- Nginx reverse proxy
- Integration with VPN container

**`profilarr.nix`**
- Profilarr custom format manager
- Container configuration
- Nginx reverse proxy

**`unpackerr.nix`**
- Automatic archive extraction
- Integration with arr services

#### Other Services

**`homepage.nix`**
- Homepage dashboard
- Widget configuration (Glances, arr services)
- Bookmarks and links
- Nginx reverse proxy

**`minecraft.nix`**
- Multiple Minecraft servers (Fabric, NeoForge)
- Server configurations
- Firewall rules
- User group membership

**`samba.nix`**
- File sharing service
- Multiple share definitions
- WSDD for Windows discovery
- Firewall configuration

**`printing.nix`**
- CUPS printing service (melaan only)

### Program Modules (`programs/`)

Desktop applications and environments.

#### `gnome.nix`
- GNOME desktop environment
- GDM display manager
- Excluded default packages
- GNOME extensions
- Automatic screen rotation

#### `pipewire.nix`
- PipeWire audio
- ALSA support
- PulseAudio compatibility

#### `flatpak.nix`
- Flatpak service

#### `steam.nix`
- Steam gaming platform

### User Modules (`users/`)

User configurations with both NixOS and Home Manager aspects.

#### `oscar.nix`
**NixOS aspect:**
- User account definition
- Shell configuration (zsh)
- SSH authorized keys
- Extra packages (rcon-cli)
- Home Manager integration

**Home Manager aspect:**
- Shell configuration (zsh with antidote plugins)
- Git configuration
- Emacs setup
- Starship prompt
- direnv and fzf
- Host-specific packages (prismlauncher on melaan)

#### `adelline.nix`
**NixOS aspect:**
- User account definition
- Shell configuration (zsh)
- Home Manager integration

**Home Manager aspect:**
- Git configuration
- Basic shell setup

### Host Modules (`hosts/`)

Host-specific configurations that compose features together.

#### `harmony/`
**`flake-parts.nix`**
- Creates nixosConfiguration using `mkNixos` helper

**`configuration.nix`**
- Imports system base modules (boot, networking, nixpkgs, system-core, secrets)
- Imports infrastructure (agenix, home-manager, nginx, ssh, zfs)
- Imports all media and container services
- Imports user modules
- Imports hardware configuration
- Sets system.stateVersion

#### `melaan/`
**`flake-parts.nix`**
- Creates nixosConfiguration using `mkNixos` helper

**`configuration.nix`**
- Imports system base modules
- Imports desktop environment modules (flatpak, gnome, pipewire, printing, steam)
- Imports user modules
- Imports Framework hardware configuration
- Sets system.stateVersion

## Adding New Features

To add a new feature:

1. Create a new module file in the appropriate category directory
2. Define `flake.modules.nixos.<feature-name>` (and optionally `flake.modules.homeManager.<feature-name>`)
3. Add the feature to host configuration imports in `modules/hosts/<hostname>/configuration.nix`
4. Co-locate all related configuration (nginx vhosts, firewall rules, etc.) in the module

Example:

```nix
# modules/services/myservice.nix
{
  flake.modules.nixos.myservice = {config, pkgs, ...}: {
    services.myservice = {
      enable = true;
      port = 8080;
    };
    
    services.nginx.virtualHosts."myservice.example.com" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:8080/";
    };
    
    networking.firewall.allowedTCPPorts = [8080];
  };
}
```

Then in `modules/hosts/harmony/configuration.nix`:

```nix
imports = with inputs.self.modules.nixos; [
  # ... other modules
  myservice
];
```

## Best Practices

1. **Keep modules focused**: Each module should represent one feature or service
2. **Co-locate configuration**: Keep all configuration for a feature in its module
3. **Use imports for dependencies**: If a feature requires another, import it
4. **Avoid duplication**: Share common configuration through feature modules
5. **Document special cases**: Use comments for host-specific configuration
6. **Test incrementally**: Test new features on one host before adding to others
