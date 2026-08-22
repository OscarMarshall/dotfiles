# Repository Overview

This is a personal NixOS/nix-darwin configuration repository for multiple systems. It manages system configuration,
services, and user environments using Nix flakes, Den/Dendritic, and Home Manager.

## Systems

- **OMARSHAL-M-T2QF**: MacBook (aarch64-darwin) with development environment
- **harmony**: Home server (x86_64-linux) with media services, Minecraft servers, and more
- **melaan**: Framework laptop (x86_64-linux) running GNOME desktop
- **omarshal@dev203.meraki.com**: Standalone Home Manager config (x86_64-linux) using the `oscar` aspect on a work
  machine

## Repository Structure

This repository uses a Den-based architecture with flake-parts and import-tree for automatic module discovery.

- **`flake.nix`**: Auto-generated flake file (DO NOT EDIT - regenerated via `nix run .#write-flake`)
- **`modules/`**: Flake-parts modules auto-imported via import-tree
  - **`agenix-rekey.nix`**: Imports `agenix-rekey.flakeModule` for per-host secret rekeying
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
      - **`OMARSHAL-M-T2QF/`**: OMARSHAL-M-T2QF.nix
    - **`users/`**: User-specific aspects (one directory per user)
      - **`oscar/`**: oscar.nix, work/ (work-specific config)
      - **`adelline/`**: adelline.nix
    - **`my/`**: Reusable aspects in the `my` namespace (~43 aspects)
      - Core: boot.nix, locale.nix, nix.nix, fonts.nix
      - Services: nginx.nix, minecraft-servers.nix, paperless.nix, plex.nix, jellyfin.nix, prowlarr.nix,
        qbittorrent.nix, radarr.nix, sonarr.nix, unpackerr.nix, home-assistant.nix
      - Containers: profilarr.nix
      - Desktop: gnome.nix, pipewire.nix, steam.nix, discord.nix, ghostty.nix
      - Utilities: auto-upgrade.nix, auto-login.nix, host-flag.nix, routes.nix
      - Applications: emacs/, git.nix, gpg.nix, ssh-client.nix, ssh-server.nix
      - Infrastructure: zfs.nix, samba.nix, lm-sensors.nix, networkmanager.nix, secrets.nix, vpn-confinement.nix,
        backup.nix (offsite backups - see "Working with Offsite Backups" below)
      - Darwin: homebrew.nix
      - VM: vm.nix, vm-bootable.nix, ci-no-boot.nix
- **`secrets/`**: Directory containing ragenix/agenix-rekey-encrypted secrets (`.age` files). Primitive secrets are
  encrypted to the YubiKey master identity. Do not expose plaintext. Rekeyed OS-level host secrets live in
  `secrets/rekeyed/<hostname>/`; a user's embedded Home Manager secrets live in the separate sibling directory
  `secrets/rekeyed/<hostname>-home-<username>/` (kept separate so agenix-rekey's per-node orphan cleanup doesn't delete
  the other node's secrets). Generated (template) secrets live in `secrets/generated/`.

## Key Technologies

- **Den**: Aspect-oriented configuration system built on flake-parts (https://denful.github.io/den)
- **Dendritic**: Template and tooling for Den-based flakes with flake-file integration
- **flake-parts**: Modular flake framework for composable Nix configurations
- **import-tree**: Automatic module discovery and importing
- **flake-file**: Auto-generates flake.nix from module inputs
- **NixOS**: Declarative Linux distribution for reproducible system configurations
- **nix-darwin**: NixOS-like system configuration for macOS
- **Nix Flakes**: Modern Nix package and configuration management with lockfile-based dependency pinning
- **Home Manager**: Manages user-specific configuration (dotfiles, packages, shell, etc.) declaratively
- **ragenix**: Secret management using age encryption (drop-in Rust rewrite of agenix)
- **agenix-rekey**: Extends ragenix with YubiKey master identity, per-host rekeying, and template secret generation
- **Docker/OCI containers**: Several services run in containers for isolation (profilarr, unpackerr, etc.)

## Den Aspects Architecture

Den uses an "aspect-oriented" approach where configuration is composed from reusable aspects:

### Configuration Classes

Each aspect can provide configuration for different targets using these classes:

- **`os`**: Applies to both NixOS and Darwin (use this to avoid duplicating identical config in `nixos` and `darwin`)
- **`nixos`**: NixOS-specific configuration only
- **`darwin`**: macOS (nix-darwin) specific configuration only
- **`homeManager`**: Home Manager configuration (cross-platform user environment)
- **`hmLinux`/`hmDarwin`**: Platform-specific Home Manager classes forwarded into `homeManager` by
  `modules/aspects/defaults.nix`

### Host Aspects

Each host has its own aspect (e.g., `den.aspects.harmony`) that declares:

- Which `my.*` aspects to include (services, features, etc.)
- Host-specific NixOS/Darwin configuration
- Which users have accounts on the host
- Hardware configuration (via `hardware-configuration.nix` for NixOS hosts)

Example: `modules/aspects/hosts/harmony/harmony.nix` includes aspects like nginx, minecraft-servers, qbittorrent, etc.

### User Aspects

Each user has their own aspect (e.g., `den.aspects.oscar`) that declares:

- User display name via `user.description`
- User-specific Home Manager configuration
- Desktop applications (when on graphical hosts via direct `host.graphical` checks)
- Work-specific config (when work=true)

Example: `modules/aspects/users/oscar/oscar.nix` includes emacs, git config, gpg, ssh-client, etc.

### Reusable Aspects (`my.*`)

The `my` namespace contains ~43 reusable aspects for services, applications, and features. These are functions that
return configuration and can accept parameters (e.g., `qbittorrent { administrators = [ "oscar" ]; }`).

### Aspect Routing

The `my.routes` aspect (included in defaults) enables bidirectional aspect dependencies:

- `oscar.provides.harmony` provides user config specific to a host
- `harmony.provides.oscar` provides host config specific to a user

Example: `den.aspects.oscar.provides.harmony` could contain Oscar's harmony-specific settings.

### Host Flags

Use direct context flag checks in aspect code (hosted users or standalone homes):

- `lib.optionals (scope.graphical or false) [ ... ]` for graphical-only packages/aspects
- `lib.mkIf (scope.work or false) { ... }` for work-only settings
- Resolve `scope` from host/home context (e.g. `scope = if host != null then host else home`)

## Important Services

The **harmony** server (x86_64-linux) runs:

- **Media Stack**: Plex, Jellyfin, Tautulli, Radarr, Sonarr, Prowlarr, Autobrr, Cross-seed
- **Downloads**: native qBittorrent under VPN-Confinement
- **Minecraft**: Multiple servers via nix-minecraft
- **Home Automation**: Home Assistant, with SSO via Authentik's `auth_oidc` integration
- **Reverse Proxy**: nginx with Let's Encrypt SSL certificates
- **Monitoring**: homepage-dashboard
- **File Sharing**: Samba shares
- **Storage**: ZFS pool named "metalminds"
- **Automatic Updates**: Auto-upgrade with reboot capability
- **Infrastructure as Code**: Authentik/\*arr/DNS/Meraki config via Terraform/OpenTofu (terranix), auto-applied on
  switch - see "Working with Terraform/OpenTofu (terranix)" below
- **Offsite Backups**: Restic to Backblaze B2 for opted-in ZFS datasets - see "Working with Offsite Backups (my.backup)"
  below

The **melaan** laptop (x86_64-linux) includes:

- **Desktop Environment**: GNOME with Wayland
- **Applications**: Steam, Zen Browser, Ghostty, Krita, Rnote, PrusaSlicer
- **Framework-specific**: Hardware support via nixos-hardware
- **Users**: Oscar and Adelline

The **OMARSHAL-M-T2QF** MacBook (aarch64-darwin) includes:

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

### Darwin Systems (OMARSHAL-M-T2QF)

1. **Testing configuration**: `darwin-rebuild check --flake .#OMARSHAL-M-T2QF`
2. **Building configuration**: `darwin-rebuild build --flake .#OMARSHAL-M-T2QF`
3. **Switching configuration**: `darwin-rebuild switch --flake .#OMARSHAL-M-T2QF`

### Updating Dependencies

- Dependabot handles GitHub Actions and Nix (`flake.lock`) updates.
- Dependabot PRs are automatically set to auto-merge once required checks pass.
- Renovate is kept only for Docker image updates referenced from Nix files.
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
(OMARSHAL-M-T2QF) on macOS.

## Best Practices

1. **DO NOT EDIT flake.nix**: It's auto-generated by flake-file. Add inputs to `modules/inputs.nix` or other modules,
   then run `nix run .#write-flake` to regenerate.
2. **Secrets Management**: Secrets are managed via ragenix + agenix-rekey with a YubiKey master identity. Primitive
   secrets live in `secrets/*.age` (encrypted to YubiKey). Mark a primitive secret with `intermediary = true` only if it
   is exclusively consumed by generators (never referenced directly by services). Template/composite secrets are
   generated with `agenix generate` (human-only) and rekeyed per host with `agenix rekey -a` (human-only). Rekeyed
   outputs live in `secrets/rekeyed/<hostname>/` for OS-level secrets, and in the separate sibling directory
   `secrets/rekeyed/<hostname>-home-<username>/` for a user's embedded Home Manager secrets — kept separate so
   agenix-rekey's per-node orphan cleanup (in local storage mode) doesn't delete the other node's secrets. Never commit
   plaintext secrets or edit `.age` files directly. Use the `secrets` class (not `age.secrets` directly) to declare
   secrets in aspects — it routes to `age.secrets` on all platforms. Use `nixosSecrets` only when the secret must be
   excluded from Darwin/Home Manager (e.g. hashed login passwords). Each host that uses secrets must set
   `age.rekey.hostPubkey` in its host aspect.
3. **State Version**: Never change `system.stateVersion` or `home.stateVersion` unless you understand the implications
   (see NixOS documentation).
4. **Declarative Configuration**: All system configuration should be in Nix files; avoid imperative changes.
5. **Flake Lock**: `flake.lock` pins dependency versions. Dependabot can update it automatically, or update manually
   with `nix flake update`.
6. **Aspect Organization**:
   - Put host-specific config in `modules/aspects/hosts/<hostname>/`
   - Put user-specific config in `modules/aspects/users/<username>/`
   - Put reusable config in `modules/aspects/my/`
   - Use direct host checks (`host.graphical`, `host.work`) for conditional config
   - Use `hmLinux`/`hmDarwin` for platform-specific Home Manager config in user aspects
   - Use `os` class for config identical on NixOS and Darwin; avoid duplicating in `nixos` and `darwin`
7. **Input Management**: Declare flake inputs close to their usage in module files, not centralized in one place.
8. **Module Discovery**: Files in `modules/` are auto-imported via import-tree; no manual imports needed.
9. **Parametric Aspects**: Use functions for configurable aspects (e.g., `qbittorrent { administrators = [...]; }`)
10. **Den Documentation**: When working with aspects, refer to https://denful.github.io/den for patterns and examples.

## Security Considerations

- SSL/TLS is handled by nginx with Let's Encrypt certificates (ACME)
- Secrets are managed via ragenix + agenix-rekey with a YubiKey master identity (age encryption). Primitive secrets are
  never rekeyed directly to hosts; template secrets are generated and then rekeyed per host.
- VPN-Confinement protects qBittorrent traffic
- Firewall is enabled with specific port allowances per service
- OpenSSH is enabled for remote access on harmony
- Each aspect defines its own security requirements (firewall rules, user groups, etc.)

## Common Patterns

### Den Patterns

- **Aspect definition**:
  `den.aspects.<name> = { includes = [...]; os = {...}; nixos = {...}; darwin = {...}; homeManager = {...}; }`
- **`os` class**: Use `os = {...}` for config that applies to both NixOS and Darwin (avoids duplication)
- **`user.description`**: Set `user.description = "Full Name"` in user aspects instead of repeating in
  `os`/`nixos`/`darwin` user configs
- **Parametric aspects**: `my.<name> = params: { ... }` for configurable aspects
- **Host routing**: Use `<host>.provides.<user>` and `<user>.provides.<host>` for bidirectional config
- **Conditional config**: Use `lib.optionals (host.<flag> or false) [ ... ]` / `lib.mkIf` for conditional config
- **Taking parameters**: Use `den.lib.take.exactly` or `den.lib.take.atLeast` to extract specific context parameters
- **`secrets` class**: Use in host/user/service aspects to declare secrets — preferred over setting `age.secrets`
  directly. Forwarded into `age.secrets` on all platforms (NixOS, Darwin, Home Manager) by `defaults.nix`. Example:
  `secrets.my-secret.rekeyFile = ../../../secrets/my-secret.age;`
- **`nixosSecrets` class**: Use in user/host aspects for NixOS-only secrets (e.g. hashed passwords). Forwarded only into
  `nixos.age.secrets` by `defaults.nix`, never to Darwin or Home Manager. Use `secrets` in all other cases; only reach
  for `nixosSecrets` when the secret must be excluded from non-NixOS hosts. Requires `age.rekey.hostPubkey` set on each
  NixOS host that uses it.

### Configuration Patterns

- **File paths**: Use `/metalminds/` prefix for the ZFS storage pool on harmony
- **Primitive secret paths**: Use relative paths pointing to `secrets/`: `../../../secrets/filename.age` (adjust for
  depth). These are encrypted to the YubiKey. Add `intermediary = true` only if the secret is exclusively used by
  generators.
- **Secret declarations**: Use the `secrets` class (not `age.secrets` directly) in aspects. Example:
  `secrets.my-secret.rekeyFile = ../../../secrets/my-secret.age;` Use `nixosSecrets` only for secrets that must be
  excluded from Darwin/Home Manager.
- **Rekeyed secret references**: The rekeyed copy in `secrets/rekeyed/<hostname>/` (OS-level) or
  `secrets/rekeyed/<hostname>-home-<username>/` (embedded Home Manager) is auto-generated by `agenix rekey -a`
  (human-only).
- **Service aspects**: Each service aspect defines its own:
  - NixOS service configuration
  - Firewall rules (if network-exposed)
  - nginx virtual host (if web-accessible)
  - User groups (if requiring special permissions)
  - Secrets (if needed)
- **VPN-Confinement pattern**: `my.vpn-confinement` provides service opt-in via `vpn-confinement._.service "<name>"`;
  service aspects (e.g. qBittorrent) declare their own `vpnNamespaces` config.
- **Container aspects**: Docker containers defined with `virtualisation.oci-containers.containers.<name>`
- **Desktop aspects**: Gate graphical config with checks derived from host/home context
- **Work aspects**: Gate work config with checks derived from host/home context

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
- **OMARSHAL-M-T2QF** (aarch64-darwin): MacBook with homebrew, work configuration
- Each host aspect:
  - Includes relevant `my.*` aspects for services and features
  - Defines host-specific NixOS/Darwin configuration
  - Declares which users have accounts
  - Imports hardware-configuration.nix (NixOS hosts only)

### User Aspects (2 users)

- **oscar**: Primary user with full desktop environment, development tools, emacs, git config
  - Work-specific configuration in `oscar/work/`
  - Graphical apps (Discord, Ghostty, Zen Browser, PrusaSlicer) via direct `host.graphical` checks
- **adelline**: Secondary user on melaan with basic GNOME setup
- Each user aspect:
  - Defines user account details (name via `user.description`, hashed password, SSH keys)
  - Includes Home Manager configuration
  - Uses direct host checks for conditional desktop apps

### Reusable Aspects (`my.*` - 43 aspects)

Organized by category:

- **Core**: boot, locale, nix, fonts
- **Networking**: networkmanager, nginx
- **Services**: minecraft-servers, plex, jellyfin, prowlarr, qbittorrent, radarr, sonarr, unpackerr, autobrr,
  cross-seed, homepage, home-assistant
- **Containers**: profilarr
- **Desktop**: gnome, pipewire, steam, discord, ghostty, zen-browser, prusa-slicer, xfce-desktop
- **Development**: emacs, git, gpg, ssh-client, ssh-server
- **Infrastructure**: zfs, samba, lm-sensors, secrets, auto-upgrade, auto-login, vpn-confinement, backup (offsite
  backups via Restic/Backblaze B2)
- **Darwin**: homebrew
- **Utilities**: host-flag, routes, vm, vm-bootable, ci-no-boot

Each `my.*` aspect is a self-contained module that can be included by hosts or users.

## Capabilities and Limitations for AI Agents

### Available Capabilities

- **`nix` is available**: The Copilot environment has `nix` pre-installed. You can use it to:
  - Evaluate flake outputs: `nix flake show`, `nix flake metadata`
  - Check configuration syntax and evaluate expressions: `nix eval`
  - Build derivations to validate configuration: `nix build .#<output>`
  - Run flake apps: `nix run .#<app>` (note: `nix run .#write-flake` regenerates flake.nix)
  - The `oscarmarshall` and `nix-community` Cachix caches are configured for read-only access

### Limitations

- Cannot execute `nixos-rebuild`, `darwin-rebuild`, or `home-manager` commands (requires target system access)
- Cannot test actual service functionality (no runtime environment)
- Cannot decrypt or modify ragenix secrets
- Cannot access the actual systems (harmony, melaan, OMARSHAL-M-T2QF)
- Focus on configuration file correctness, Den aspect patterns, and NixOS/Darwin best practices
- When making changes to flake inputs in modules, regenerate flake.nix with `nix run .#write-flake`

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

Use `den.lib.take.exactly` or `den.lib.take.atLeast` to extract specific context parameters safely.

### Working with Secrets (agenix-rekey)

The `nix develop` shell provides the `agenix` CLI tool from agenix-rekey (automatically activated by direnv via the
`.envrc` in the repo root). The `agenix` script is the single tool needed to add/update/generate/rekey secrets.

> **Note**: Creating/editing primitive secrets, running `agenix generate`, and running `agenix rekey` all require
> physical access to the YubiKey and must be performed by a human. AI agents cannot perform these steps.

**Creating or editing a primitive secret (human only):**

```bash
agenix edit secrets/<name>.age
```

**Adding a new primitive secret:**

1. Add a `secrets.<name>` entry with `rekeyFile` (and `intermediary = true` if it is only used by generators) in the
   relevant aspect.
2. **Human step**: Run `agenix edit secrets/<name>.age` to encrypt the value.

**Adding a new template/generated secret:**

1. Define a `generator` block in the relevant `secrets.<name>` entry (see existing aspects for examples).
2. **Human step**: Run `agenix generate` to produce the template secret in `secrets/generated/`.

**Rekeying after adding a host or changing secrets (human only):**

```bash
agenix rekey -a
git add -A secrets/rekeyed/
```

Each host that consumes rekeyed secrets must declare `age.rekey.hostPubkey` in its host aspect.

### Working with Terraform/OpenTofu (terranix)

Some live services aren't configured through Nix directly, but through their own APIs - Authentik SSO clients, \*arr app
wiring, DNS records, the Meraki router. These are managed as Terraform/OpenTofu config generated from Nix via
[terranix](https://terranix.org) (`modules/terranix.nix`). Any aspect can contribute resources by declaring a `terranix`
field, merged per-host the same way `nixos`/`darwin`/`homeManager` are.

Each host that uses this gets its own `nix run .#<host>-tf*` commands (currently only `harmony-tf`) - `.plan`,
`.destroy`, `nix develop .#<host>-tf` for a shell with `opentofu`, `nix build .#<host>-tf.config` to inspect the
generated `config.tf.json`. The bare `nix run .#<host>-tf` (no suffix) **applies**.

**These only work when run on the host itself** (e.g. on harmony, never from a dev laptop or CI): both Terraform state
and the decrypted secrets env file are host-local now, not repo- or YubiKey-backed -

- **State**: lives on the host's own ZFS dataset (`backend.local.path` in `modules/terranix.nix`), not committed to git.
  Moving it requires a one-time `tofu init -migrate-state`, done by hand.
- **Secrets**: a `settings.terraform`-flagged secret (see that convention documented at the top of
  `modules/terranix.nix`) is collected into `<host>-tf.env`, decrypted unattended to `/run/agenix/<host>-tf.env` by the
  host's own agenix activation (same as any other secret on that host) - no YubiKey needed there. AI agents running
  these commands only have this available when working directly on the host (e.g. over SSH); running them from a repo
  checkout elsewhere will silently skip secrets and then fail on missing provider credentials.

**Automated apply**: `harmony-tf-apply.service` (a systemd oneshot, `wantedBy multi-user.target` + `restartTriggers` on
the generated config and lock file) plans and applies automatically whenever a `nixos-rebuild switch` changes anything
Terraform-relevant - manual `nix run .#harmony-tf` is normally only needed to preview a change or investigate a failure.
It never auto-applies a plan containing a destroy action (checked via `tofu show -json | jq`); that fails the service
instead, surfaced through the same Netdata → Discord alerting used for host health, not through a blocked
`nixos-rebuild switch` (the trigger is decoupled and non-blocking).

### Working with Offsite Backups (my.backup)

Any ZFS dataset opts into offsite backup by setting `backup = true;` (or a `pkgs: {...}` function, for datasets that
need pkgs-derived overrides - e.g. nextcloud.nix's and immich.nix's own database-dump prepare/cleanup pairs, or
minecraft-servers.nix's tmux-based world quiescing) on its `dataset` record - see the shape documented at the top of
`modules/aspects/my/zfs.nix`. `my.backup` (`modules/aspects/my/backup.nix`) collects every opted-in dataset on a host
into a `services.restic.backups` job against a Backblaze B2 bucket, which it also declares via the `b2` terranix
provider (30-day Object Lock retention - see that file's own comments for why the restic prune policy has to cover at
least that window).

Two credentials, not one: an account-level B2 key (shared across every host - `accountApplicationKeyId`, a plain `let`
constant in `backup.nix` itself, not a per-host parameter) authenticates the Terraform provider that creates buckets; a
second, bucket-scoped key (`applicationKeyId`, a genuine per-host `my.backup` parameter, secret named
`backup-b2-application-key-<hostname>`) is what restic uses day to day. Both key _IDs_ are plain Nix values, not
secrets - Backblaze documents them as non-sensitive - only the keys themselves are.

**Bootstrap order for a new host** (the bucket-scoped key genuinely can't exist before its bucket does):

1. Wire in `(backup { bucket = "<name>"; })` with no `applicationKeyId` yet - it defaults to `null`, under which
   `my.backup` schedules no restic jobs at all (verify with
   `nix eval .#nixosConfigurations.<host>.config.services.restic.backups`) and doesn't even declare the `backup-b2-env`
   secret, so there's nothing for a stray `agenix generate` to generate wrong in the meantime.
2. **Human step**: create the account-level B2 key, if one doesn't already exist for this Backblaze account (no bucket
   restriction - it needs to be able to create one), set `accountApplicationKeyId` in `backup.nix`,
   `agenix edit secrets/b2-application-key.age` with it, `agenix rekey -a`. Only needed once ever, not per host.
3. `nix run .#<host>-tf` (on the host itself - see "Working with Terraform/OpenTofu" above) to create the bucket.
4. **Human step**: create the bucket-scoped B2 key against the now-existing bucket,
   `agenix edit secrets/backup-b2-application-key-<hostname>.age` with it, `agenix rekey -a`.
5. Set `applicationKeyId` for real, rebuild. `nix eval` the same `services.restic.backups` path again to confirm the
   jobs now exist before considering this done.

AI agents can verify every step above with `nix eval`/`nix build` except the two marked human steps (creating the B2
keys, `agenix edit`, `agenix rekey` - all require the YubiKey, per "Working with Secrets" above) and confirming an
actual backup run succeeded (`journalctl -u restic-backups-<dataset>.service` on the host, over SSH - not available to
agents without direct host access).

## Documentation Update Policy

Whenever making changes that affect documented behaviour (secrets architecture, adding hosts/users/services, changing
build/deploy steps, modifying the aspect system), **always update both `README.md` and
`.github/copilot-instructions.md`** in the same commit or PR. This ensures the documentation stays accurate for both
human readers and AI agents working on this repository.

If a user's request contradicts existing documented conventions, update the documentation to reflect the new direction
in the same change — documentation should always match the actual conventions in use, not prior ones.
