# qBittorrent Migration Summary

## Changes Made

This PR migrates qBittorrent from a NixOS service using VPN-Confinement to a Docker container using gluetun for VPN connectivity. It also removes VPN-Confinement from all other services since they only need access to qBittorrent, not to the VPN directly.

## Key Changes

### Configuration Changes (`configuration.nix`)

1. **Removed:**
   - `services.qbittorrent` service configuration
   - `systemd.services.*.vpnConfinement` configuration for all services
   - `vpnNamespaces.proton0` entire configuration
   - `Harmony_P2P-US-CA-898.conf` secret reference (replaced by gluetun.env)
   - Cross-seed headers file ownership (was owned by qbittorrent user)

2. **Added:**
   - `gluetun` Docker container - Handles VPN connectivity with ProtonVPN
   - `qbittorrent` Docker container - Runs qBittorrent in gluetun's network namespace
   - System user and group `qbittorrent` for cross-seed compatibility
   - User `oscar` added to `docker` group

3. **Updated:**
   - `cross-seed` configuration now explicitly sets user/group and qBittorrent URL
   - `unpackerr` configuration includes qBittorrent URL and points to services at 127.0.0.1
   - `autobrr` now binds to 127.0.0.1 instead of 192.168.15.1
   - nginx proxy for all services (except qBittorrent) now use `proxy` instead of `proxyProton0`
   - qBittorrent nginx proxy still uses `proxyProton0` to connect to Docker container at 192.168.15.1:8080

### Flake Changes (`flake.nix`)

- Removed `vpn-confinement` input and module since it's no longer used

### Secrets Configuration (`secrets/secrets.nix`)

- Added `gluetun.env.age` entry for VPN credentials
- Removed `Harmony_P2P-US-CA-898.conf.age` entry (no longer needed)

### Documentation

- Created `GLUETUN_SETUP.md` with detailed setup instructions

## What Works Out of the Box

- OCI containers with default backend
- Gluetun container will start and connect to ProtonVPN (once secret is created)
- qBittorrent container will start and run through VPN
- All services (autobrr, prowlarr, radarr, sonarr) run directly on the host without VPN
- Nginx proxy will route traffic correctly for all services
- Cross-seed is configured to connect to qBittorrent
- Unpackerr is configured to connect to qBittorrent and other services

## What Requires Manual Steps

### 1. Create the gluetun.env.age Secret (REQUIRED)

Before deploying, you MUST create the `secrets/gluetun.env.age` file:

```bash
# Extract values from your existing WireGuard config
# Then create and encrypt the secret:
agenix -e secrets/gluetun.env.age
```

The file should contain:
```
WIREGUARD_PRIVATE_KEY=your_private_key
WIREGUARD_ADDRESSES=your_wireguard_address
SERVER_COUNTRIES=US
```

See `GLUETUN_SETUP.md` for detailed instructions on extracting these values.

### 2. Configure qBittorrent via WebUI (After First Deployment)

After the containers start, you'll need to configure qBittorrent settings that were previously managed by NixOS:

- Username and password
- BitTorrent session settings (max torrents, default tags, etc.)
- WebUI settings (reverse proxy, trusted domains)
- AutoRun script for cross-seed integration

See `GLUETUN_SETUP.md` for the exact settings to configure.

### 3. Update API Keys in Connected Services

Update qBittorrent connection settings in:
- Autobrr
- Radarr  
- Sonarr
- Any other services using qBittorrent API

## Testing the Migration

After deployment, verify:

1. **VPN Connection:**
   ```bash
   docker logs gluetun  # Should show successful VPN connection
   docker exec gluetun wget -qO- ifconfig.me  # Should show VPN IP
   ```

2. **qBittorrent Access:**
   - WebUI: https://qbittorrent.harmony.silverlight-nex.us
   - API: http://192.168.15.1:8080

3. **Service Connectivity:**
   - Cross-seed can connect to qBittorrent
   - Autobrr can connect to qBittorrent
   - Radarr/Sonarr can connect to qBittorrent

## Rollback Plan

If you need to rollback:

1. Revert the commits:
   ```bash
   git revert HEAD~2..HEAD
   ```

2. Rebuild the NixOS configuration:
   ```bash
   sudo nixos-rebuild switch --flake .#harmony
   ```

The original qBittorrent service will be restored with VPN-Confinement.

## Benefits of This Change

1. **Simpler VPN Management:** gluetun is a dedicated VPN container with better ProtonVPN support
2. **Better Container Support:** qBittorrent in Docker is more flexible and easier to update
3. **Isolation:** Docker containers provide better process isolation
4. **Easier Debugging:** Docker logs are simpler to access and troubleshoot
5. **Portable Configuration:** Docker compose could be used in the future if needed

## Network Architecture

```
Internet
   ↓
Proton VPN (via gluetun)
   ↓
qBittorrent container (shares gluetun's network)
   ↓ (port 8080 exposed via gluetun)
Host Network (192.168.15.1:8080)
   ↓
Nginx Reverse Proxy
   ↓
https://qbittorrent.harmony.silverlight-nex.us
```

Other services (Radarr, Sonarr, etc.) connect to qBittorrent via:
- `http://192.168.15.1:8080` (host network)

## Files Changed

- `configuration.nix` - Main configuration with Docker containers
- `secrets/secrets.nix` - Added gluetun.env.age entry
- `GLUETUN_SETUP.md` - Setup and migration documentation (new)
- `MIGRATION_SUMMARY.md` - This file (new)
