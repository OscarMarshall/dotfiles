# Repository Overview

This is a personal NixOS configuration repository for multiple systems. It manages system configuration, services, and user environment using NixOS flakes, Home Manager, and the **Dendritic Design Pattern** with flake-parts.

## Systems

- **harmony**: Home server with media services, Minecraft servers, and more
- **melaan**: Framework laptop running GNOME desktop

## Repository Structure

- **`flake.nix`**: Main flake configuration using flake-parts.lib.mkFlake with import-tree for automatic module discovery
- **`modules/`**: Dendritic feature modules organized by category
  - **`lib/`**: Helper functions and development tools
    - `default.nix`: Helper for creating NixOS configurations (mkNixos)
    - `dev-tools.nix`: Pre-commit hooks, formatter, and dev shell
  - **`system/`**: Core system configuration modules
    - `agenix.nix`: Agenix secret management integration
    - `boot.nix`: Boot loader configuration (latest kernel)
    - `home-manager.nix`: Home Manager integration
    - `networking.nix`: Network settings, host IDs, NetworkManager
    - `nixpkgs.nix`: Nixpkgs config and overlays
    - `secrets.nix`: Secret path definitions
    - `system-core.nix`: Core system settings (auto-upgrade, nix settings, locale, timezone, zsh)
    - `zfs.nix`: ZFS filesystem configuration
  - **`services/`**: Service modules (one per service)
    - `apcupsd.nix`: APC UPS daemon
    - `autobrr.nix`: Autobrr service with nginx
    - `cross-seed.nix`: Cross-seed torrent service
    - `glances.nix`: System monitoring
    - `gluetun.nix`: VPN container
    - `homepage.nix`: Homepage dashboard with nginx
    - `lm_sensors.nix`: Hardware monitoring
    - `minecraft.nix`: Minecraft servers (Fabric and NeoForge)
    - `nginx.nix`: Base nginx with ACME
    - `plex.nix`: Plex media server with nginx
    - `printing.nix`: CUPS printing service
    - `profilarr.nix`: Profilarr container with nginx
    - `prowlarr.nix`: Prowlarr and Flaresolverr with nginx
    - `qbittorrent.nix`: qBittorrent container with nginx
    - `radarr.nix`: Radarr service with nginx
    - `samba.nix`: File sharing
    - `sonarr.nix`: Sonarr service with nginx
    - `ssh.nix`: SSH and tmux
    - `unpackerr.nix`: Unpackerr container
  - **`programs/`**: Desktop programs and applications
    - `flatpak.nix`: Flatpak service
    - `gnome.nix`: GNOME desktop environment
    - `pipewire.nix`: Audio with pipewire
    - `steam.nix`: Steam gaming platform
  - **`users/`**: User configurations with both NixOS and Home Manager aspects
    - `oscar.nix`: Oscar's user account and home-manager config
    - `adelline.nix`: Adelline's user account and home-manager config
  - **`hosts/`**: Host-specific configurations
    - **`harmony/`**: Home server configuration
      - `flake-parts.nix`: Creates nixosConfiguration
      - `configuration.nix`: Imports feature modules for this host
    - **`melaan/`**: Laptop configuration
      - `flake-parts.nix`: Creates nixosConfiguration
      - `configuration.nix`: Imports feature modules for this host
- **`systems/`**: Hardware-specific files (auto-generated)
  - `harmony/hardware-configuration.nix`: Hardware config
  - `melaan/hardware-configuration.nix`: Hardware config
- **`cachix.nix`**: Binary cache configuration
- **`secrets/`**: Agenix-encrypted secrets (`.age` files) - DO NOT modify or expose these files
- **`secrets/secrets.nix`**: Public keys for agenix encryption
- **`docs/`**: Documentation
  - `MODULE-ORGANIZATION.md`: Detailed module documentation

## Architecture: Dendritic Design Pattern

This configuration uses the **Dendritic Design Pattern** which provides:

- **Feature-based organization**: Each module represents a feature (service, app, or configuration aspect)
- **Bottom-up composition**: Features define their requirements; hosts import features they need
- **Co-location**: All configuration for a feature lives in one place (service config, nginx vhost, firewall rules, etc.)
- **Reusability**: Features can be easily shared between hosts and imported by other features

### Module Pattern

Each feature module follows this structure:

```nix
{inputs, ...}: {
  flake.modules.nixos.<feature-name> = {config, pkgs, ...}: {
    # NixOS configuration for this feature
    # Can import other features via imports
  };
  
  flake.modules.homeManager.<feature-name> = {pkgs, ...}: {
    # Home Manager configuration (optional)
  };
}
```

Features can import other features, and hosts compose features together declaratively.

## Key Technologies

- **NixOS**: Declarative Linux distribution that allows reproducible system configurations
- **Nix Flakes**: Modern Nix package and configuration management with lockfile-based dependency pinning
- **flake-parts**: Framework for organizing flake outputs into composable modules
- **import-tree**: Automatic discovery and importing of all modules in a directory tree
- **Home Manager**: Manages user-specific configuration (dotfiles, packages, shell, etc.) declaratively
- **agenix**: Secret management using age encryption to securely store sensitive data in the repository
- **Docker/OCI containers**: Several services run in containers for isolation and ease of management (gluetun, qBittorrent, etc.)

## Important Services

The harmony server runs multiple services including:

- **Media Stack**: Plex, Radarr, Sonarr, Prowlarr, qBittorrent (via VPN)
- **VPN**: gluetun container providing VPN with port forwarding
- **Minecraft**: Multiple servers via nix-minecraft
- **Reverse Proxy**: nginx with Let's Encrypt SSL certificates
- **Monitoring**: homepage-dashboard, glances
- **File Sharing**: Samba shares
- **Storage**: ZFS pool named "metalminds"

The melaan laptop includes:

- **Desktop Environment**: GNOME with Wayland
- **Applications**: Steam, Chrome, Ghostty, Krita, Rnote
- **Framework-specific**: Hardware support via nixos-hardware

## Building and Deploying

This is a NixOS system configuration, not a traditional software project. Changes are applied by:

1. **Testing configuration**: Use `nixos-rebuild test --flake .#<system>` to test changes without modifying boot configuration
2. **Building configuration**: Use `nixos-rebuild build --flake .#<system>` to build the configuration
3. **Switching configuration**: Use `nixos-rebuild switch --flake .#<system>` to apply and activate changes
4. **Updating flake inputs**: Use `nix flake update` to update dependencies

Where `<system>` is either `harmony` or `melaan`.

Note: These commands typically require root/sudo access and are run on the target system, not in a CI environment.

## Validation

- **Syntax check**: `nix flake check` validates flake syntax
- **Evaluation check**: `nix flake show` displays the flake outputs
- **Build check harmony**: `nixos-rebuild build --flake .#harmony` builds the harmony configuration without applying it
- **Build check melaan**: `nixos-rebuild build --flake .#melaan` builds the melaan configuration without applying it

## Best Practices

1. **Secrets Management**: All secrets are encrypted using agenix. Never commit plaintext secrets or modify `.age` files directly
2. **State Version**: Never change `system.stateVersion` or `home.stateVersion` unless you understand the implications (see comments in files)
3. **Declarative Configuration**: All system configuration should be in Nix files, avoid imperative changes
4. **Flake Lock**: `flake.lock` pins dependency versions; update explicitly with `nix flake update`
5. **Feature Modules**: Each feature should be self-contained with all related configuration (service, nginx, firewall, users) co-located
6. **Module Organization**: Features are organized by category (system, services, programs, users, hosts)
7. **System-Level vs User-Level**: System-wide configs go in system modules; user-specific configs go in home-manager
8. **Host Composition**: Hosts import only the features they need from their configuration.nix

## Security Considerations

- SSL/TLS is handled by nginx with Let's Encrypt certificates (ACME)
- Secrets are managed via agenix with age encryption
- VPN (gluetun) protects qBittorrent traffic
- Firewall is enabled with specific port allowances
- OpenSSH is enabled for remote access

## Common Patterns

- Feature modules define `flake.modules.nixos.<feature-name>` (and optionally `flake.modules.homeManager.<feature-name>`)
- Features can import other features via `imports = with inputs.self.modules.nixos; [feature1 feature2];`
- Service modules include co-located nginx virtual hosts where applicable
- Docker containers are defined in individual service modules
- Firewall rules are co-located with the services that need them
- File paths use `/metalminds/` prefix for the ZFS storage pool
- Secret paths in modules use relative paths: `../../secrets/filename.age`
- User packages are managed in home-manager, not NixOS user packages
- System-wide settings (like defaultUserShell) go in system-core.nix

## Module Organization

The configuration follows the dendritic design pattern with these categories:

- **lib/** (2 modules): Helper functions and dev tools
- **system/** (8 modules): Core system config (boot, networking, nixpkgs, system-core, secrets, zfs, agenix, home-manager)
- **services/** (19 modules): Service modules (nginx, plex, minecraft, arr stack, etc.)
- **programs/** (4 modules): Desktop applications (gnome, steam, flatpak, pipewire)
- **users/** (2 modules): User configs with NixOS + Home Manager aspects (oscar, adelline)
- **hosts/** (2 hosts): Host-specific feature composition (harmony, melaan)

Each feature module is self-contained with related configuration co-located together. See `docs/MODULE-ORGANIZATION.md` for detailed documentation.

## Limitations for AI Agents

- Cannot execute `nixos-rebuild` commands (requires target system access)
- Cannot test actual service functionality (no runtime environment)
- Cannot decrypt or modify agenix secrets
- Cannot access the actual "harmony" or "melaan" systems
- Focus on configuration file correctness and NixOS best practices
- All modules are automatically discovered by import-tree; manual imports in flake.nix are not needed
