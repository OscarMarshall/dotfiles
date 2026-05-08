# NixOS/Darwin Configuration with Den

This repository contains my personal system configurations for multiple machines using Nix, managed through the
[Den](https://vic.github.io/den) aspect-oriented configuration framework.

## Systems

- **harmony** (x86_64-linux): Home server running media services, Minecraft servers, and infrastructure
- **melaan** (x86_64-linux): Framework laptop with GNOME desktop
- **OMARSHAL-M-2FD2** (aarch64-darwin): MacBook with development environment

## Quick Start

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- Appropriate system (NixOS, macOS, or Linux for home-manager only)

### Clone and Build

```console
git clone https://github.com/OscarMarshall/dotfiles.git
cd dotfiles
```

### Apply Configuration

**NixOS systems (harmony, melaan):**

```console
sudo nixos-rebuild switch --flake .#<hostname>
```

**macOS systems (OMARSHAL-M-2FD2):**

```console
darwin-rebuild switch --flake .#OMARSHAL-M-2FD2
```

### Validate Configuration

```console
# nix flake check currently fails due to cross-architecture issues
# Use platform-specific builds instead:
nix build .#nixosConfigurations.harmony.config.system.build.toplevel
nix build .#nixosConfigurations.melaan.config.system.build.toplevel
nix build .#darwinConfigurations.OMARSHAL-M-2FD2.config.system.build.toplevel

# Show available outputs
nix flake show

# Format code
nix fmt
```

## Architecture

This repository uses **Den**, an aspect-oriented configuration system built on flake-parts. Configuration is organized
into composable aspects:

### Aspects Structure

- **`modules/aspects/hosts/`**: Host-specific configurations (one aspect per host)
- **`modules/aspects/users/`**: User-specific configurations (one aspect per user)
- **`modules/aspects/my/`**: Reusable service and feature aspects (~43 total)
- **`modules/aspects/defaults.nix`**: Default includes applied to all configurations

### Configuration Classes

Each aspect can provide configuration for different targets using these classes:

- **`os`**: Applies to both NixOS and Darwin (avoids duplicating identical config in `nixos` and `darwin`)
- **`nixos`**: NixOS-specific configuration only
- **`darwin`**: macOS (nix-darwin) specific configuration only
- **`homeManager`**: Home Manager configuration (cross-platform user environment)
- **`hmLinux`/`hmDarwin`**: Platform-specific Home Manager classes forwarded into `homeManager` by
  `modules/aspects/defaults.nix`

### Host Aspects

Each host declares which services and features to enable:

```nix
# modules/aspects/hosts/harmony/harmony.nix
den.aspects.harmony = {
  includes = with my; [
    nginx
    (minecraft-servers { administrators = [ "oscar" ]; })
    (qbittorrent { administrators = [ "oscar" ]; })
    plex
    # ... more aspects
  ];
};
```

### User Aspects

Each user declares their environment and applications:

```nix
# modules/aspects/users/oscar/oscar.nix
den.aspects.oscar = { host, lib, ... }: {
  user.description = "Oscar Marshall";

  includes = [
    my.emacs
    my.git
  ] ++ lib.optionals (host.graphical or false) [ my.discord my.ghostty ];
};
```

Use an aspect function signature (`{ host, lib, ... }:`) when you need context-aware conditional logic.

## Key Features

### Services

- **Media**: Plex, Radarr, Sonarr, Prowlarr, Autobrr, Cross-seed
- **Downloads**: native qBittorrent confined with VPN-Confinement
- **Gaming**: Minecraft servers
- **Infrastructure**: Nginx reverse proxy with Let's Encrypt, Samba file sharing, ZFS storage

The VPN input and service confinement opt-in are provided by a reusable `my.vpn-confinement` aspect, while qBittorrent
declares the `proton0` namespace directly in its own aspect.

### Desktop

- **GNOME** on melaan (Wayland, via NixOS)
- **macOS desktop**: Fonts, Homebrew-based applications, and Nix-managed development environment on OMARSHAL-M-2FD2
- **Applications**: Emacs, Ghostty terminal, Zen Browser, Discord, Steam, Krita, PrusaSlicer
- **Framework laptop** support via nixos-hardware

### Development

- **Emacs** with doom configuration
- **Git** with per-machine configuration
- **GPG** and SSH setup
- **Shell**: Fish shell via Home Manager

## Secrets Management

Secrets are managed with [ragenix](https://github.com/yaxitech/ragenix) (age encryption) extended by
[agenix-rekey](https://github.com/oddlama/agenix-rekey). A YubiKey acts as the single master identity; host keys are
derived automatically. Primitive secrets are encrypted to the YubiKey. Mark a primitive secret `intermediary = true`
only if it is exclusively consumed by generators (never referenced directly by services). Template secrets (env files,
JSON configs) are generated from primitives and then rekeyed per host.

The dev shell (automatically activated by [direnv](https://direnv.net/) via the `.envrc` in the repo root) provides the
`agenix` CLI tool from agenix-rekey, which is the single script needed to add/update/generate/rekey secrets.

> **Note**: Editing primitive secrets, running `agenix generate`, and running `agenix rekey` require physical YubiKey
> access and must be performed by a human.

```console
# Edit or create a primitive secret (human only — requires YubiKey)
agenix edit secrets/<name>.age

# Generate template secrets from primitives (human only — requires YubiKey)
agenix generate
git add secrets/generated/

# Rekey all secrets for all hosts and commit (human only — requires YubiKey)
agenix rekey -a
git add secrets/rekeyed/harmony/
git add secrets/rekeyed/melaan/
```

### Secrets Architecture

- **Primitive secrets** (`secrets/*.age`): encrypted to the YubiKey master identity. Add `intermediary = true` only if
  the secret is exclusively consumed by generators.
- **Template secrets**: generated from primitives by `agenix generate` into `secrets/generated/`, then rekeyed per host
  via `agenix rekey -a` into `secrets/rekeyed/<hostname>/`.
- **`secrets` class**: use in host/user/service aspects to declare secrets — preferred over setting `age.secrets`
  directly. Forwarded to `age.secrets` on all platforms (NixOS, Darwin, Home Manager) by `defaults.nix`.
- **`nixosSecrets` class**: used in user/host aspects for NixOS-only secrets (e.g. hashed passwords). Forwarded only to
  `nixos.age.secrets`, never to Darwin or Home Manager configs. Prefer `secrets` unless the secret must be excluded from
  non-NixOS hosts.

Each host that consumes rekeyed secrets must declare `age.rekey.hostPubkey` in its host aspect.

## Updating

### Update All Dependencies

```console
nix flake update
```

### Update Specific Input

```console
nix flake update <input-name>
```

### Regenerate flake.nix

The `flake.nix` is auto-generated by [flake-file](https://github.com/vic/flake-file). After modifying inputs in
`modules/inputs.nix`:

```console
nix run .#write-flake
```

## Adding New Configuration

### Add a New Service

1. Create `modules/aspects/my/<service>.nix`
2. Define the aspect (with parameters if needed)
3. Include in host's aspect: `modules/aspects/hosts/<hostname>/<hostname>.nix`

### Add a New Host

#### NixOS host

1. Create `modules/aspects/hosts/<hostname>/<hostname>.nix`
2. Add a NixOS `hardware-configuration.nix` for the host
3. Declare the host in `modules/den.nix`

#### Darwin host

1. Create `modules/aspects/hosts/<hostname>/<hostname>.nix`
2. Configure the host-specific nix-darwin options in your aspect
3. Declare the host in `modules/den.nix`

### Add a New User

1. Create `modules/aspects/users/<username>/<username>.nix`
2. Add user to host declarations in `modules/den.nix`

## Documentation

- [Den Documentation](https://vic.github.io/den) - Aspect system patterns and usage
- [Dendritic Template](https://github.com/vic/den/tree/main/templates/dendritic) - Template this repo is based on
- [NixOS Manual](https://nixos.org/manual/nixos/stable/) - NixOS configuration reference
- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Home Manager options
- [nix-darwin Manual](https://daiderd.com/nix-darwin/manual/index.html) - macOS system configuration

## License

This is a personal configuration repository. Feel free to use it as reference or template for your own configurations.
