# NixOS Configuration

This repository contains the NixOS configuration for the Harmony server.

## Repository Structure

The configuration is organized into modular components for better maintainability. See [docs/MODULE-ORGANIZATION.md](docs/MODULE-ORGANIZATION.md) for detailed documentation on the module structure.

- **`flake.nix`**: Main flake configuration defining inputs and outputs
- **`configuration.nix`**: Top-level configuration that imports all modules
- **`hardware-configuration.nix`**: Hardware-specific configuration (auto-generated)
- **`home.nix`**: Home Manager configuration for user "oscar"
- **`cachix.nix`**: Binary cache configuration
- **`modules/`**: Modular configuration organized by functionality:
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
  - `services.nix`: Miscellaneous system services
  - `sonarr.nix`: Sonarr service and nginx config
  - `system.nix`: Core system settings, programs, and system packages
  - `unpackerr.nix`: Unpackerr container
  - `users.nix`: User account definitions
  - `zfs.nix`: ZFS filesystem and services configuration

## Development

This configuration includes:

- [Alejandra](https://github.com/kamadorueda/alejandra): An opinionated Nix code formatter
- [deadnix](https://github.com/astro/deadnix): A tool to scan for unused Nix code

Both are integrated with [git-hooks.nix](https://github.com/cachix/git-hooks.nix) for automatic checks on commit.

### Setting up pre-commit hooks

To enable automatic formatting and dead code checks on commit:

```bash
nix develop
```

This will set up the pre-commit hooks. After this, whenever you commit changes to `.nix` files:

- Alejandra will automatically format them
- deadnix will check for unused code and fail the commit if any is found

### Manual formatting

To manually format all Nix files in the repository:

```bash
nix fmt
```

Or to format specific files:

```bash
nix fmt path/to/file.nix
```

### Running checks

To run all configured checks (including pre-commit hooks):

```bash
nix flake check
```

To automatically fix statix issues:

```bash
nix run nixpkgs#statix -- fix
```

### CI Enforcement

GitHub Actions automatically run on all pull requests and pushes to main/master branches to ensure:

- Code is properly formatted (via Alejandra and Prettier)
- Nix code follows best practices (via statix)
- Flake configuration is healthy (via flake-checker)

This provides a safety net in case local pre-commit hooks are bypassed.

### Automated Dependency Updates

This repository uses [Renovate Bot](https://docs.renovatebot.com/) to automatically check for updates to Docker image versions used in OCI containers.

Renovate runs daily at midnight UTC and will automatically create pull requests when updates are available. The configuration is in `renovate.json` and includes:

- Custom regex matching to detect Docker images in `.nix` files

Docker images are pinned to specific versions for reproducibility and stability.

## Usage

Build and switch to the configuration:

```bash
sudo nixos-rebuild switch --flake .#harmony
```
