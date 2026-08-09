# NixOS/Darwin Configuration with Den

This repository contains my personal system configurations for multiple machines using Nix, managed through the
[Den](https://denful.github.io/den) aspect-oriented configuration framework.

## Systems

- **harmony** (x86_64-linux): Home server running media services, Minecraft servers, and infrastructure
- **melaan** (x86_64-linux): Framework laptop with GNOME desktop
- **OMARSHAL-M-T2QF** (aarch64-darwin): MacBook with development environment
- **omarshal@dev203.meraki.com** (x86_64-linux): Standalone Home Manager config reusing the `oscar` aspect for a work
  machine

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

**macOS systems (OMARSHAL-M-T2QF):**

```console
darwin-rebuild switch --flake .#OMARSHAL-M-T2QF
```

**Standalone Home Manager (omarshal@dev203.meraki.com):**

```console
home-manager switch --flake .#"omarshal@dev203.meraki.com"
```

### Validate Configuration

```console
# nix flake check currently fails due to cross-architecture issues
# Use platform-specific builds instead:
nix build .#nixosConfigurations.harmony.config.system.build.toplevel
nix build .#nixosConfigurations.melaan.config.system.build.toplevel
nix build .#darwinConfigurations.OMARSHAL-M-T2QF.config.system.build.toplevel

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
- **`modules/aspects/my/`**: Reusable service and feature aspects (~55 total)
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

- **Media**: Plex, Tautulli, Radarr, Sonarr, Prowlarr, Unpackerr, Autobrr, Cross-seed
- **Downloads**: native qBittorrent confined with VPN-Confinement
- **Gaming**: Minecraft servers
- **Home Automation**: Home Assistant, with SSO via Authentik's `auth_oidc` integration
- **Infrastructure**: Nginx reverse proxy with Let's Encrypt, Samba file sharing, ZFS storage, offsite backups
  (Restic/Backblaze B2)

The VPN input and service confinement opt-in are provided by a reusable `my.vpn-confinement` aspect, while qBittorrent
declares the `proton0` namespace directly in its own aspect.

### Desktop

- **GNOME** on melaan (Wayland, via NixOS)
- **macOS desktop**: Fonts, Homebrew-based applications, and Nix-managed development environment on OMARSHAL-M-T2QF
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
git add secrets/<name>.age

# Generate template secrets from primitives (human only — requires YubiKey)
agenix generate -a

# Rekey all secrets for all hosts and commit (human only — requires YubiKey)
agenix rekey -a
```

### Secrets Architecture

- **Primitive secrets** (`secrets/*.age`): encrypted to the YubiKey master identity. Add `intermediary = true` only if
  the secret is exclusively consumed by generators.
- **Template secrets**: generated from primitives by `agenix generate` into `secrets/generated/`, then rekeyed via
  `agenix rekey -a` into `secrets/rekeyed/<hostname>/` for the host's OS-level secrets, and
  `secrets/rekeyed/<hostname>-home-<username>/` for a user's embedded Home Manager secrets. These are kept as separate
  directories (rather than sharing one) because `agenix rekey`'s local storage mode deletes any file in a directory it
  doesn't recognize as one of that node's own secrets — sharing a directory between the OS and Home Manager nodes would
  cause each to delete the other's secrets as "orphans".
- **`secrets` class**: use in host/user/service aspects to declare secrets — preferred over setting `age.secrets`
  directly. Forwarded to `age.secrets` on all platforms (NixOS, Darwin, Home Manager) by `defaults.nix`.
- **`nixosSecrets` class**: used in user/host aspects for NixOS-only secrets (e.g. hashed passwords). Forwarded only to
  `nixos.age.secrets`, never to Darwin or Home Manager configs. Prefer `secrets` unless the secret must be excluded from
  non-NixOS hosts.

Each host that consumes rekeyed secrets must declare `age.rekey.hostPubkey` in its host aspect.

## Infrastructure as Code (Terranix/OpenTofu)

Some live services aren't configured through Nix directly, but through their own APIs — Authentik SSO clients, \*arr app
wiring, DNS records, the Meraki router. These are managed as Terraform/OpenTofu config instead, generated from Nix via
[terranix](https://terranix.org) (see `modules/terranix.nix`). Any aspect can contribute resources by declaring a
`terranix` field, the same way it would declare `nixos`/`darwin`/`homeManager`.

Each host that uses this gets its own `nix run .#<host>-tf*` commands (currently only `harmony-tf`):

```console
nix run .#harmony-tf.plan      # preview changes
nix run .#harmony-tf           # apply
nix run .#harmony-tf.destroy
nix develop .#harmony-tf       # shell with opentofu
nix build .#harmony-tf.config  # inspect the generated config.tf.json
```

These only work when run **on the host itself** (e.g. on harmony, never from a dev laptop): both Terraform state and the
decrypted secrets env file live on the host's own local ZFS dataset/`/run/agenix`, not in this repo or on the YubiKey
master identity. `harmony-tf-apply.service` also plans and applies automatically on every `nixos-rebuild switch` that
changes anything Terraform-relevant, so running these by hand is normally only needed to preview a change or investigate
a failure — a plan containing any destroy action is never auto-applied; it fails the service instead, surfaced through
the same Netdata → Discord alerting used for host health.

## Offsite Backups (Restic/Backblaze B2)

Any ZFS dataset can opt into offsite backup by setting `backup = true;` (or a `pkgs: {...}` function, for datasets that
need pkgs-derived overrides like a database dump prepare/cleanup pair) on its `dataset` declaration — see
`modules/aspects/my/zfs.nix` for the full `dataset` record shape. The `my.backup` aspect
(`modules/aspects/my/backup.nix`) picks up every opted-in dataset on a host and turns it into a
`services.restic.backups` job against a [Backblaze B2](https://www.backblaze.com/cloud-storage) bucket, with a 30-day
Object Lock retention policy so even a compromised restic key can't delete recent backups.

```nix
# modules/aspects/hosts/<hostname>/<hostname>.nix
(backup {
  bucket = "<globally-unique-b2-bucket-name>";
  applicationKeyId = "<bucket-scoped Backblaze application key ID>"; # omit (defaults to null) until the key exists
})
```

Credentials: an account-level Backblaze application key (shared across every host — there's one Backblaze account, so
its ID is a plain constant in `backup.nix` itself, not a per-host parameter) authenticates the `b2` Terraform provider
that creates the bucket; a second, bucket-scoped key (per host, named `backup-b2-application-key-<hostname>`) is what
restic actually uses day to day. The bucket-scoped key can't exist before its bucket does, so a new host's bootstrap
order is: wire in `my.backup` with just `bucket` set, `nix run .#<hostname>-tf` to create the bucket (see
[Infrastructure as Code](#infrastructure-as-code-terranixopentofu) above), create the bucket-scoped key against it, then
set `applicationKeyId` and rebuild. Until `applicationKeyId` is set, no restic jobs are scheduled at all — see
`backup.nix`'s own comments for why that matters.

## Updating

GitHub automation:

- Dependabot handles GitHub Actions and Nix (`flake.lock`) updates.
- Dependabot PRs are automatically set to auto-merge once required checks pass.
- Renovate is kept only for Docker image updates referenced from Nix files.

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

- [Den Documentation](https://denful.github.io/den) - Aspect system patterns and usage
- [Dendritic Template](https://github.com/denful/den/tree/main/templates/dendritic) - Template this repo is based on
- [NixOS Manual](https://nixos.org/manual/nixos/stable/) - NixOS configuration reference
- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Home Manager options
- [nix-darwin Manual](https://daiderd.com/nix-darwin/manual/index.html) - macOS system configuration

## License

This is a personal configuration repository. Feel free to use it as reference or template for your own configurations.
