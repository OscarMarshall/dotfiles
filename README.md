# NixOS Configuration

This repository contains the NixOS configurations for multiple systems.

## Systems

- **harmony**: Home server with media services, Minecraft servers, and more
- **melaan**: Framework laptop running GNOME desktop
- **OMARSHAL-M-2FD2**: Oscar's work MacBook Pro running nix-darwin

## Repository Structure

The configuration is organized into modular components for better maintainability. See [docs/MODULE-ORGANIZATION.md](docs/MODULE-ORGANIZATION.md) for detailed documentation on the module structure.

- **`flake.nix`**: Main flake configuration defining inputs and outputs
- **`systems/`**: System-specific configuration directories
  - **`harmony/`**: Configuration files for the harmony server
    - `configuration.nix`: Top-level configuration that imports all modules
    - `hardware-configuration.nix`: Hardware-specific configuration (auto-generated)
  - **`melaan/`**: Configuration files for the melaan laptop
    - `configuration.nix`: GNOME desktop and user configuration
    - `hardware-configuration.nix`: Framework-specific hardware configuration
  - **`omarshal-m-2fd2/`**: Configuration files for the OMARSHAL-M-2FD2 MacBook Pro
    - `configuration.nix`: nix-darwin system configuration
- **`homes/`**: Home Manager configurations
  - `oscar.nix`: Oscar's home-manager configuration (used on harmony and melaan)
  - `adelline.nix`: Adelline's home-manager configuration (used on harmony and melaan)
  - `omarshal.nix`: Oscar's home-manager configuration for macOS (used on OMARSHAL-M-2FD2)
- **`cachix.nix`**: Binary cache configuration
- **`modules/`**: Modular configuration organized by functionality (used by harmony):
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
  - `users.nix`: User account definitions (shared across systems)
  - `zfs.nix`: ZFS filesystem and services configuration

## Development

This configuration includes development tools integrated with [git-hooks.nix](https://github.com/cachix/git-hooks.nix) for automatic checks on commit:

- [Alejandra](https://github.com/kamadorueda/alejandra): An opinionated Nix code formatter
- [flake-checker](https://github.com/DeterminateSystems/flake-checker): A tool to check flake health
- [statix](https://github.com/nerdypepper/statix): A linter for Nix code
- [Prettier](https://prettier.io/): A code formatter for JSON, Markdown, and YAML files

### Setting up pre-commit hooks

To enable automatic checks and formatting on commit:

```bash
nix develop
```

This will set up the pre-commit hooks. After this, whenever you commit changes:

- Alejandra will automatically format Nix files
- flake-checker will verify flake health
- statix will lint Nix code for common issues
- Prettier will format JSON, Markdown, and YAML files

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

#### Setting up Renovate

To enable Renovate, you need to create a `RENOVATE_TOKEN` secret in your repository settings:

1. Go to your repository's **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `RENOVATE_TOKEN`
4. Value: A GitHub Personal Access Token (PAT) with the following permissions:
   - `repo` scope (for private repositories) or `public_repo` scope (for public repositories)
   - `workflow` scope (if you want Renovate to update GitHub Actions workflows)

To create a PAT:

1. Go to GitHub **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token** → **Generate new token (classic)**
3. Select the required scopes mentioned above
4. Copy the token and add it as the `RENOVATE_TOKEN` secret

## Usage

Build and switch to a configuration:

```bash
# For harmony server (NixOS)
sudo nixos-rebuild switch --flake .#harmony

# For melaan laptop (NixOS)
sudo nixos-rebuild switch --flake .#melaan

# For OMARSHAL-M-2FD2 MacBook Pro (nix-darwin)
darwin-rebuild switch --flake .#OMARSHAL-M-2FD2
```
