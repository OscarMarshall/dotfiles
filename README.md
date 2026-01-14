# NixOS Configuration

This repository contains the NixOS configurations for multiple systems using the [Dendritic Design Pattern](https://github.com/Doc-Steve/dendritic-design-with-flake-parts) with [flake-parts](https://flake.parts).

## Systems

- **harmony**: Home server with media services, Minecraft servers, and more
- **melaan**: Framework laptop running GNOME desktop

## Architecture

This configuration follows the **Dendritic Design Pattern**, which provides:

- **Reusable code**: Feature modules can be easily integrated into various systems
- **Simple troubleshooting**: Errors can be quickly identified in a single location
- **Logical structure**: Modules are organized by category and purpose

### Key Concepts

The dendritic pattern shifts from a *top-down* (hosts define services) to a *bottom-up* (features define configurations for different contexts) approach. Each feature is a module that defines what it does in different configuration contexts (NixOS, Home Manager, etc.).

## Repository Structure

- **`flake.nix`**: Main flake configuration using flake-parts and import-tree
- **`modules/`**: Dendritic feature modules organized by category
  - **`lib/`**: Helper functions and development tools
    - `default.nix`: Helper for creating NixOS configurations
    - `dev-tools.nix`: Pre-commit hooks, formatter, and dev shell
  - **`system/`**: Core system configuration modules
    - `agenix.nix`: Agenix secret management integration
    - `boot.nix`: Boot loader configuration (latest kernel)
    - `home-manager.nix`: Home Manager integration
    - `networking.nix`: Network settings, host IDs, NetworkManager
    - `nixpkgs.nix`: Nixpkgs config and overlays
    - `secrets.nix`: Secret path definitions
    - `system-core.nix`: Core system settings (auto-upgrade, nix settings, locale, timezone)
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
- **`systems/`**: Hardware-specific files
  - `harmony/hardware-configuration.nix`: Auto-generated hardware config
  - `melaan/hardware-configuration.nix`: Auto-generated hardware config
- **`cachix.nix`**: Binary cache configuration
- **`secrets/`**: Agenix-encrypted secrets (`.age` files)
- **`docs/`**: Documentation
  - `MODULE-ORGANIZATION.md`: Detailed module documentation

## Module Organization

Each feature module follows the pattern:

```nix
{inputs, ...}: {
  flake.modules.nixos.<feature-name> = {config, pkgs, ...}: {
    # NixOS configuration for this feature
  };
  
  flake.modules.homeManager.<feature-name> = {pkgs, ...}: {
    # Home Manager configuration for this feature (if applicable)
  };
}
```

Features can:
- Import other features via `imports = with inputs.self.modules.nixos; [feature1 feature2];`
- Define configurations for multiple contexts (nixos, homeManager, darwin)
- Include all related configuration (services, nginx vhosts, firewall rules, user groups, etc.)

## Building and Deploying

### Testing Configuration

```bash
# Test without modifying boot configuration
nixos-rebuild test --flake .#harmony
nixos-rebuild test --flake .#melaan
```

### Building Configuration

```bash
# Build without activating
nixos-rebuild build --flake .#harmony
nixos-rebuild build --flake .#melaan
```

### Applying Configuration

```bash
# Apply and activate changes
nixos-rebuild switch --flake .#harmony
nixos-rebuild switch --flake .#melaan
```

### Updating Dependencies

```bash
# Update flake inputs (nixpkgs, home-manager, etc.)
nix flake update
```

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
# For harmony server
sudo nixos-rebuild switch --flake .#harmony

# For melaan laptop
sudo nixos-rebuild switch --flake .#melaan
```
