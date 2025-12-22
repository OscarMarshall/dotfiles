# NixOS Configuration

This repository contains the NixOS configuration for the Harmony server.

## Development

This configuration includes [Alejandra](https://github.com/kamadorueda/alejandra), an opinionated Nix code formatter, integrated with [git-hooks.nix](https://github.com/cachix/git-hooks.nix) for automatic code formatting.

### Setting up pre-commit hooks

To enable automatic formatting on commit:

```bash
nix develop
```

This will set up the pre-commit hooks. After this, whenever you commit changes to `.nix` files, Alejandra will automatically format them.

### Manual formatting

To manually format all Nix files in the repository:

```bash
nix fmt
```

### Running checks

To run all configured checks (including pre-commit hooks):

```bash
nix flake check
```

### CI Enforcement

A GitHub Action automatically runs on all pull requests and pushes to main/master branches to ensure code is properly formatted. This provides a safety net in case local pre-commit hooks are bypassed.

## Usage

Build and switch to the configuration:

```bash
sudo nixos-rebuild switch --flake .#harmony
```
