# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Apply Configuration

```bash
# NixOS (harmony, melaan)
sudo nixos-rebuild switch --flake .#<hostname>

# macOS
darwin-rebuild switch --flake .#OMARSHAL-M-2FD2

# Standalone Home Manager
home-manager switch --flake .#"omarshal@dev203.meraki.com"
```

### Build Without Applying

```bash
nix build .#nixosConfigurations.harmony.config.system.build.toplevel
nix build .#nixosConfigurations.melaan.config.system.build.toplevel
nix build .#darwinConfigurations.OMARSHAL-M-2FD2.config.system.build.toplevel
```

### Format

```bash
nix fmt
```

### Update Dependencies

```bash
nix flake update              # all inputs
nix flake update <input-name> # single input
```

### Regenerate flake.nix

`flake.nix` is **auto-generated** by [flake-file](https://github.com/vic/flake-file) — never edit it directly. After
changing inputs in `modules/inputs.nix` (or any module that declares `flake-file.inputs`):

```bash
nix run .#write-flake
```

## Architecture

This repo uses **Den**, an aspect-oriented configuration framework built on flake-parts. All modules are loaded via
`import-tree ./modules`, so any `.nix` file under `modules/` is automatically picked up.

### Aspect Classes

Each aspect can provide configuration through named classes:

| Class                  | Target                                                                         |
| ---------------------- | ------------------------------------------------------------------------------ |
| `os`                   | Both NixOS and Darwin (avoids duplication)                                     |
| `nixos`                | NixOS only                                                                     |
| `darwin`               | macOS (nix-darwin) only                                                        |
| `homeManager`          | Home Manager (cross-platform)                                                  |
| `hmLinux` / `hmDarwin` | Platform-specific Home Manager, forwarded into `homeManager` by `defaults.nix` |
| `secrets`              | Forwarded to `age.secrets` on all platforms                                    |
| `nixosSecrets`         | Forwarded only to NixOS `age.secrets` (e.g. hashed passwords)                  |

### Module Layout

- **`modules/aspects/my/`** — Reusable service/feature aspects (the `my` namespace). These are the building blocks.
- **`modules/aspects/hosts/<hostname>/`** — Host-specific aspects that compose `my.*` aspects via `includes`.
- **`modules/aspects/users/<username>/`** — User-specific aspects.
- **`modules/aspects/defaults.nix`** — Applied to all configurations: forwards `hmLinux`/`hmDarwin` → `homeManager`, and
  `secrets` → `age.secrets` on all platforms.
- **`modules/den.nix`** — Declares all hosts and their users; also defines the schema defaults (what every host/user
  gets automatically).
- **`modules/inputs.nix`** — Base flake inputs (nixpkgs, home-manager, darwin, etc.).

### Hosts

| Hostname                     | Arch           | Type                                        |
| ---------------------------- | -------------- | ------------------------------------------- |
| `harmony`                    | x86_64-linux   | NixOS home server (media, Minecraft, infra) |
| `melaan`                     | x86_64-linux   | NixOS Framework laptop with GNOME           |
| `OMARSHAL-M-2FD2`            | aarch64-darwin | MacBook (nix-darwin)                        |
| `omarshal@dev203.meraki.com` | x86_64-linux   | Standalone Home Manager (work machine)      |

### Adding a New Service Aspect

1. Create `modules/aspects/my/<service>.nix` defining `my.<service>`.
2. Include it in the relevant host aspect: `modules/aspects/hosts/<hostname>/<hostname>.nix`.

Aspects that need parameters are defined as functions:

```nix
my.<service> = { param, ... }: { ... };
# used as:
includes = [ (my.<service> { param = value; }) ];
```

Use `{ host, lib, ... }:` as the aspect function signature when you need conditional logic based on host properties
(`host.graphical`, `host.work`, etc.).

## Secrets

Secrets use [ragenix](https://github.com/yaxitech/ragenix) + [agenix-rekey](https://github.com/oddlama/agenix-rekey). A
YubiKey is the master identity; rekeyed secrets live in `secrets/rekeyed/<hostname>/`.

The dev shell (activated automatically via `.envrc`/direnv) provides the `agenix` CLI. Operations requiring the YubiKey
must be run by a human:

```bash
agenix edit secrets/<name>.age       # create/edit a primitive secret
agenix generate && git add secrets/generated/  # generate template secrets
agenix rekey -a && git add secrets/rekeyed/*/  # rekey for all hosts
```

In aspect code, use the `secrets` class (not `age.secrets` directly) — `defaults.nix` forwards it to the right place on
every platform. Use `nixosSecrets` only when a secret must be excluded from Darwin/Home Manager.

## Formatting

nixfmt (strict, 120-column) for Nix files; prettier (120-column, prose-wrap always) for everything else. Enforced by
pre-commit hooks (run automatically in the dev shell via `nix develop`).
