# Repository Overview

This is a personal NixOS configuration repository for a home server named "harmony". It manages system configuration, services, and user environment using NixOS flakes and Home Manager.

## Repository Structure

- **`flake.nix`**: Main flake configuration defining inputs (nixpkgs, agenix, home-manager, nix-minecraft) and the NixOS system configuration
- **`configuration.nix`**: Primary NixOS system configuration including services, networking, users, and Docker containers
- **`hardware-configuration.nix`**: Hardware-specific configuration (auto-generated)
- **`home.nix`**: Home Manager configuration for user "oscar" (shell, editor, git, etc.)
- **`cachix.nix`**: Binary cache configuration
- **`secrets/`**: Directory containing agenix-encrypted secrets (`.age` files) - DO NOT modify or expose these files
- **`secrets/secrets.nix`**: Public keys for agenix encryption

## Key Technologies

- **NixOS**: Declarative Linux distribution
- **Nix Flakes**: Modern Nix package and configuration management
- **Home Manager**: User environment management
- **agenix**: Secret management with age encryption
- **Docker/OCI containers**: Several services run in containers (gluetun, qBittorrent, etc.)

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
5. **Service Configuration**: Most services are configured declaratively via NixOS options
6. **Docker Containers**: Defined in `virtualisation.oci-containers.containers` in configuration.nix
7. **User Groups**: User "oscar" has specific group memberships for service access (minecraft, qbittorrent, radarr, sonarr, wheel)

## Security Considerations

- SSL/TLS is handled by nginx with Let's Encrypt certificates (ACME)
- Secrets are managed via agenix with age encryption
- VPN (gluetun) protects qBittorrent traffic
- Firewall is enabled with specific port allowances
- OpenSSH is enabled for remote access

## Common Patterns

- Services are typically enabled with `services.<name>.enable = true`
- Docker containers include environment variables, volumes, and network configuration
- nginx virtual hosts follow a pattern with SSL, ACME, and reverse proxy to local ports
- File paths use `/metalminds/` prefix for the ZFS storage pool

## Limitations for AI Agents

- Cannot execute `nixos-rebuild` commands (requires target system access)
- Cannot test actual service functionality (no runtime environment)
- Cannot decrypt or modify agenix secrets
- Cannot access the actual "harmony" server
- Focus on configuration file correctness and NixOS best practices
