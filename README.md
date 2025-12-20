# NixOS Configuration

This repository contains the NixOS configuration for the `harmony` system.

## Pre-commit Hooks

This repository uses [git-hooks.nix](https://github.com/cachix/git-hooks.nix) to automatically run code quality checks before commits.

### Enabled Hooks

- **deadnix**: Scans Nix files for dead code (unused variables and bindings)

### Setup

To enable pre-commit hooks in your development environment:

```bash
nix develop
```

This will:
1. Install the necessary tools (including deadnix)
2. Set up git hooks automatically
3. Run the hooks on every commit

### Manual Checks

To manually run all pre-commit checks without committing:

```bash
nix flake check
```

### Bypassing Hooks

If you need to commit without running hooks (not recommended):

```bash
git commit --no-verify
```

## Usage

Build and switch to the configuration:

```bash
sudo nixos-rebuild switch --flake .#harmony
```

Update flake inputs:

```bash
nix flake update
```
