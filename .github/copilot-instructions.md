# Repository Overview

This is a personal NixOS/nix-darwin configuration repository for multiple systems. It manages system configuration,
services, and user environments using Nix flakes, Den/Dendritic, and Home Manager.

## Systems

- **OMARSHAL-M-2FD2**: MacBook (aarch64-darwin) with development environment
- **harmony**: Home server (x86_64-linux) with media services, Minecraft servers, and more
- **melaan**: Framework laptop (x86_64-linux) running GNOME desktop

## Repository Structure

This repository uses a Den-based architecture with flake-parts and import-tree for automatic module discovery.

- **`flake.nix`**: Auto-generated flake file (DO NOT EDIT - regenerated via `nix run .#write-flake`)
- **`modules/`**: Flake-parts modules auto-imported via import-tree
  - **`den.nix`**: Defines all hosts and homes with their aspect assignments
  - **`dendritic.nix`**: Dendritic flake module configuration
  - **`inputs.nix`**: Common flake input declarations (inputs can be declared in any module)
  - **`namespace.nix`**: Creates the `my` aspects namespace
  - **`git-hooks.nix`**: Pre-commit hooks configuration
  - **`treefmt-nix.nix`**: Code formatting configuration
  - **`vm.nix`**: VM-related flake outputs
  - **`aspects/`**: Den aspects organized by category
    - **`defaults.nix`**: Default includes for all hosts/users (routes, home-manager, user creation, etc.)
    - **`hosts/`**: Host-specific aspects (one directory per host)
      - **`harmony/`**: harmony.nix, hardware-configuration.nix
      - **`melaan/`**: melaan.nix, hardware-configuration.nix
      - **`OMARSHAL-M-2FD2/`**: OMARSHAL-M-2FD2.nix
    - **`users/`**: User-specific aspects (one directory per user)
      - **`oscar/`**: oscar.nix, work/ (work-specific config)
      - **`adelline/`**: adelline.nix
    - **`my/`**: Reusable aspects in the `my` namespace (~43 aspects)
      - Core: boot.nix, locale.nix, nix.nix, fonts.nix
      - Services: nginx.nix, minecraft-servers.nix, plex.nix, prowlarr.nix, radarr.nix, sonarr.nix
      - Containers: gluetun.nix, qbittorrent.nix, profilarr.nix, unpackerr.nix
      - Desktop: gnome.nix, pipewire.nix, steam.nix, discord.nix, ghostty.nix
      - Utilities: auto-upgrade.nix, auto-login.nix, host-flag.nix, routes.nix
      - Applications: emacs/, git.nix, gpg.nix, ssh-client.nix, ssh-server.nix
      - Infrastructure: zfs.nix, samba.nix, lm-sensors.nix, networkmanager.nix, secrets.nix
      - Darwin: homebrew.nix
      - VM: vm.nix, vm-bootable.nix, ci-no-boot.nix
- **`secrets/`**: Directory containing ragenix-encrypted secrets (`.age` files) - edit using ragenix, do not expose
  plaintext
- **`secrets/secrets.nix`**: Public keys for ragenix encryption

## Key Technologies

- **Den**: Aspect-oriented configuration system built on flake-parts (https://vic.github.io/den)
- **Dendritic**: Template and tooling for Den-based flakes with flake-file integration
- **flake-parts**: Modular flake framework for composable Nix configurations
- **import-tree**: Automatic module discovery and importing
- **flake-file**: Auto-generates flake.nix from module inputs
- **NixOS**: Declarative Linux distribution for reproducible system configurations
- **nix-darwin**: NixOS-like system configuration for macOS
- **Nix Flakes**: Modern Nix package and configuration management with lockfile-based dependency pinning
- **Home Manager**: Manages user-specific configuration (dotfiles, packages, shell, etc.) declaratively
- **ragenix**: Secret management using age encryption (drop-in Rust rewrite of agenix)
- **Docker/OCI containers**: Several services run in containers for isolation (gluetun, qBittorrent, etc.)

## Den Aspects Architecture

Den uses an "aspect-oriented" approach where configuration is composed from reusable aspects:

### Host Aspects

Each host has its own aspect (e.g., `den.aspects.harmony`) that declares:

- Which `my.*` aspects to include (services, features, etc.)
- Host-specific NixOS/Darwin configuration
- Which users have accounts on the host
- Hardware configuration (via `hardware-configuration.nix` for NixOS hosts)

Example: `modules/aspects/hosts/harmony/harmony.nix` includes aspects like nginx, minecraft-servers, qbittorrent, etc.

### User Aspects

Each user has their own aspect (e.g., `den.aspects.oscar`) that declares:

- User information (name, email, shell)
- User-specific Home Manager configuration
- Desktop applications (when on graphical hosts via host-flag)
- Work-specific config (when work=true)

Example: `modules/aspects/users/oscar/oscar.nix` includes emacs, git config, gpg, ssh-client, etc.

### Reusable Aspects (`my.*`)

The `my` namespace contains ~43 reusable aspects for services, applications, and features. These are functions that
return configuration and can accept parameters (e.g., `qbittorrent { administrators = [ "oscar" ]; }`).

### Aspect Routing

The `my.routes` aspect (included in defaults) enables bidirectional aspect dependencies:

- `<user>._.<host>` provides user config specific to a host
- `<host>._.<user>` provides host config specific to a user

Example: `oscar._.harmony` could contain Oscar's harmony-specific settings.

### Host Flags

The `host-flag` helper conditionally includes aspects based on host properties:

- `host-flag "graphical" { ... }` includes aspects only on graphical hosts
- `host-flag "work" { ... }` includes aspects only on work machines

## Important Services

The **harmony** server (x86_64-linux) runs:

- **Media Stack**: Plex, Radarr, Sonarr, Prowlarr, Autobrr, Cross-seed
- **Downloads**: qBittorrent in gluetun VPN container with port forwarding
- **Minecraft**: Multiple servers via nix-minecraft
- **Reverse Proxy**: nginx with Let's Encrypt SSL certificates
- **Monitoring**: homepage-dashboard
- **File Sharing**: Samba shares
- **Storage**: ZFS pool named "metalminds"
- **Automatic Updates**: Auto-upgrade with reboot capability

The **melaan** laptop (x86_64-linux) includes:

- **Desktop Environment**: GNOME with Wayland
- **Applications**: Steam, Zen Browser, Ghostty, Krita, Rnote, PrusaSlicer
- **Framework-specific**: Hardware support via nixos-hardware
- **Users**: Oscar and Adelline

The **OMARSHAL-M-2FD2** MacBook (aarch64-darwin) includes:

- **Homebrew**: Package manager with automatic updates and cleanup
- **Development**: Emacs, Git, GPG, SSH
- **Work**: Work-specific configuration

## Building and Deploying

This repository uses flake-file/Dendritic which auto-generates `flake.nix`. Changes are applied differently depending on
the system type:

### NixOS Systems (harmony, melaan)

1. **Testing configuration**: `sudo nixos-rebuild test --flake .#<system>`
2. **Building configuration**: `nixos-rebuild build --flake .#<system>`
3. **Switching configuration**: `sudo nixos-rebuild switch --flake .#<system>`

### Darwin Systems (OMARSHAL-M-2FD2)

1. **Testing configuration**: `darwin-rebuild check --flake .#OMARSHAL-M-2FD2`
2. **Building configuration**: `darwin-rebuild build --flake .#OMARSHAL-M-2FD2`
3. **Switching configuration**: `darwin-rebuild switch --flake .#OMARSHAL-M-2FD2`

### Updating Dependencies

- **Update all inputs**: `nix flake update`
- **Update specific input**: `nix flake update <input-name>`
- **Regenerate flake.nix**: `nix run .#write-flake` (must be run manually after changing inputs in any module)

### Testing VMs

- **Run VM**: `nix run .#vm` (if VM configuration exists)

Note: Build/switch commands typically require appropriate permissions and are run on the target system.

## Validation

- **Syntax check**: `nix flake check` validates flake and all configurations (note: currently fails due to
  nix-doom-emacs-unstraightened cross-architecture build issues)
- **Show outputs**: `nix flake show` displays all flake outputs (hosts, homes, packages, etc.)
- **Metadata**: `nix flake metadata` shows input information
- **Build check (NixOS)**: `nixos-rebuild build --flake .#<host>` builds a NixOS configuration
- **Build check (Darwin)**: `darwin-rebuild build --flake .#<host>` builds a Darwin configuration
- **Build check (Home)**: `home-manager build --flake .#<home>` builds a home configuration
- **Formatting**: `nix fmt` formats Nix code (configured via treefmt-nix)

CI builds specific hosts on appropriate platforms: Linux hosts (harmony, melaan) on Ubuntu, Darwin hosts
(OMARSHAL-M-2FD2) on macOS.

## Best Practices

1. **DO NOT EDIT flake.nix**: It's auto-generated by flake-file. Add inputs to `modules/inputs.nix` or other modules,
   then run `nix run .#write-flake` to regenerate.
2. **Secrets Management**: All secrets are encrypted using ragenix (age). Never commit plaintext secrets or modify
   `.age` files directly.
3. **State Version**: Never change `system.stateVersion` or `home.stateVersion` unless you understand the implications
   (see NixOS documentation).
4. **Declarative Configuration**: All system configuration should be in Nix files; avoid imperative changes.
5. **Flake Lock**: `flake.lock` pins dependency versions; update explicitly with `nix flake update`.
6. **Aspect Organization**:
   - Put host-specific config in `modules/aspects/hosts/<hostname>/`
   - Put user-specific config in `modules/aspects/users/<username>/`
   - Put reusable config in `modules/aspects/my/`
   - Use `host-flag` for conditional includes based on host properties
7. **Input Management**: Declare flake inputs close to their usage in module files, not centralized in one place.
8. **Module Discovery**: Files in `modules/` are auto-imported via import-tree; no manual imports needed.
9. **Parametric Aspects**: Use functions for configurable aspects (e.g., `qbittorrent { administrators = [...]; }`)
10. **Den Documentation**: When working with aspects, refer to https://vic.github.io/den for patterns and examples.

## Security Considerations

- SSL/TLS is handled by nginx with Let's Encrypt certificates (ACME)
- Secrets are managed via ragenix with age encryption
- VPN (gluetun) protects qBittorrent traffic
- Firewall is enabled with specific port allowances per service
- OpenSSH is enabled for remote access on harmony
- Each aspect defines its own security requirements (firewall rules, user groups, etc.)

## Common Patterns

### Den Patterns

- **Aspect definition**:
  `den.aspects.<name> = { includes = [...]; nixos = {...}; darwin = {...}; homeManager = {...}; }`
- **Parametric aspects**: `my.<name> = params: { ... }` for configurable aspects
- **Host routing**: Use `host._.user` and `user._.host` for bidirectional config
- **Conditional config**: Use `host-flag "property" { includes = [...]; }` for conditional includes
- **Taking parameters**: Use `den.lib.take.exactly` or `den.lib.take.atLeast` to extract specific context parameters

### Configuration Patterns

- **File paths**: Use `/metalminds/` prefix for the ZFS storage pool on harmony
- **Secret paths**: Use relative paths in aspects: `../../../secrets/filename.age` (adjust for depth)
- **Service aspects**: Each service aspect defines its own:
  - NixOS service configuration
  - Firewall rules (if network-exposed)
  - nginx virtual host (if web-accessible)
  - User groups (if requiring special permissions)
  - Secrets (if needed)
- **Container aspects**: Docker containers defined with `virtualisation.oci-containers.containers.<name>`
- **Desktop aspects**: Use `host-flag "graphical"` to conditionally include desktop apps
- **Work aspects**: Use `host-flag "work"` or check `user.work or false` for work-specific config

### Module Structure

- **Host aspects**: Located in `modules/aspects/hosts/<hostname>/<hostname>.nix`
- **User aspects**: Located in `modules/aspects/users/<username>/<username>.nix`
- **Reusable aspects**: Located in `modules/aspects/my/<aspect-name>.nix`
- **Multi-file aspects**: Can use directories (e.g., `my/emacs/emacs.nix` with supporting files)
- **Hardware config**: NixOS hosts include `hardware-configuration.nix` alongside the main aspect file

## Aspect Organization

The configuration uses Den aspects organized into three main categories:

### Host Aspects (3 hosts)

- **harmony** (x86_64-linux): Server configuration with media services, Minecraft, nginx, ZFS, etc.
- **melaan** (x86_64-linux): Desktop laptop with GNOME, Framework hardware support, multiple users
- **OMARSHAL-M-2FD2** (aarch64-darwin): MacBook with homebrew, work configuration
- Each host aspect:
  - Includes relevant `my.*` aspects for services and features
  - Defines host-specific NixOS/Darwin configuration
  - Declares which users have accounts
  - Imports hardware-configuration.nix (NixOS hosts only)

### User Aspects (2 users)

- **oscar**: Primary user with full desktop environment, development tools, emacs, git config
  - Work-specific configuration in `oscar/work/`
  - Graphical apps (Discord, Ghostty, Zen Browser, PrusaSlicer) via host-flag
- **adelline**: Secondary user on melaan with basic GNOME setup
- Each user aspect:
  - Defines user account details (name, description, hashed password, SSH keys)
  - Includes Home Manager configuration
  - Uses host-flag for conditional desktop apps

### Reusable Aspects (`my.*` - 43 aspects)

Organized by category:

- **Core**: boot, locale, nix, fonts
- **Networking**: networkmanager, nginx
- **Services**: minecraft-servers, plex, prowlarr, radarr, sonarr, autobrr, cross-seed, homepage
- **Containers**: gluetun, qbittorrent, profilarr, unpackerr
- **Desktop**: gnome, pipewire, steam, discord, ghostty, zen-browser, prusa-slicer, xfce-desktop
- **Development**: emacs, git, gpg, ssh-client, ssh-server
- **Infrastructure**: zfs, samba, lm-sensors, secrets, auto-upgrade, auto-login
- **Darwin**: homebrew
- **Utilities**: host-flag, routes, vm, vm-bootable, ci-no-boot

Each `my.*` aspect is a self-contained module that can be included by hosts or users.

## Limitations for AI Agents

- Cannot execute `nixos-rebuild`, `darwin-rebuild`, or `home-manager` commands (requires target system access)
- Cannot test actual service functionality (no runtime environment)
- Cannot decrypt or modify ragenix secrets
- Cannot access the actual systems (harmony, melaan, OMARSHAL-M-2FD2)
- Cannot run `nix run .#write-flake` to regenerate flake.nix (but can modify modules/inputs.nix)
- Focus on configuration file correctness, Den aspect patterns, and NixOS/Darwin best practices
- When making changes to flake inputs in modules, note that flake.nix regeneration is required

## Working with This Repository

### Adding a New Service

1. Create a new aspect in `modules/aspects/my/<service-name>.nix`
2. Define the aspect as a function if it needs parameters
3. Include service configuration, firewall rules, nginx config (if needed)
4. Add the aspect to the relevant host's `includes` list in `modules/aspects/hosts/<hostname>/<hostname>.nix`

### Adding a New Host

1. Create directory `modules/aspects/hosts/<hostname>/`
2. Add `<hostname>.nix` with aspect definition and includes
3. Add `hardware-configuration.nix` (usually copied from target system)
4. Add host declaration in `modules/den.nix`

### Adding a New User

1. Create directory `modules/aspects/users/<username>/`
2. Add `<username>.nix` with user aspect definition
3. Include user in host declarations in `modules/den.nix`

### Modifying Flake Inputs

1. Edit `modules/inputs.nix` or add inputs to specific modules
2. Note in commit that `nix run .#write-flake` needs to be run
3. The flake.nix will be auto-regenerated when the command is run

### Understanding Aspect Context

Den aspects receive context parameters like:

- `host`: Host information (hostName, architecture, users)
- `user`: User information (userName, aspect name)
- `home`: Home configuration (stateVersion)
- `OS`: NixOS-specific context
- `HM`: Home Manager-specific context

Use `den.lib.take.exactly` or `den.lib.take.atLeast` to extract specific context parameters safely.
