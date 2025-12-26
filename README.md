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
  - `boot.nix`: Boot loader and ZFS configuration
  - `containers.nix`: OCI container definitions (gluetun, qBittorrent, profilarr, unpackerr)
  - `media-services.nix`: Media server services (Plex, *arr stack, homepage-dashboard)
  - `minecraft.nix`: Minecraft server configurations
  - `networking.nix`: Network settings and firewall rules
  - `nginx.nix`: Reverse proxy and SSL configuration
  - `nixpkgs.nix`: Nixpkgs overlays and package settings
  - `samba.nix`: File sharing configuration
  - `secrets.nix`: Agenix secret definitions
  - `services.nix`: Miscellaneous system services
  - `system.nix`: Core system settings (timezone, locale, auto-upgrade, state version)
  - `users.nix`: User accounts and system packages

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
nix fmt .
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

To manually check for dead code:

```bash
nix run nixpkgs#deadnix -- .
```

To automatically remove dead code:

```bash
nix run nixpkgs#deadnix -- --edit .
```

### CI Enforcement

GitHub Actions automatically run on all pull requests and pushes to main/master branches to ensure:
- Code is properly formatted (via Alejandra)
- No dead code exists (via deadnix)

This provides a safety net in case local pre-commit hooks are bypassed.

## Usage

Build and switch to the configuration:

```bash
sudo nixos-rebuild switch --flake .#harmony
```
