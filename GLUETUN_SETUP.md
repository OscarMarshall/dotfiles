# Gluetun Setup for qBittorrent

This configuration uses gluetun to provide VPN connectivity for qBittorrent running in a Docker container.

## Required Secret Configuration

You need to create the `secrets/gluetun.env.age` file with the following environment variables for ProtonVPN WireGuard:

```bash
# Create a plain text file first with the following content:
cat > /tmp/gluetun.env << 'EOF'
WIREGUARD_PRIVATE_KEY=your_private_key_here
WIREGUARD_ADDRESSES=your_wireguard_address_here
SERVER_COUNTRIES=US
EOF

# Then encrypt it using agenix:
agenix -e secrets/gluetun.env.age
# Paste the content from /tmp/gluetun.env and save
```

## Extracting WireGuard Configuration from Existing Config

If you have an existing WireGuard configuration file (like `Harmony_P2P-US-CA-898.conf`), you can extract the required values:

1. **WIREGUARD_PRIVATE_KEY**: This is the value from the `PrivateKey` field in the `[Interface]` section
2. **WIREGUARD_ADDRESSES**: This is the value from the `Address` field in the `[Interface]` section (e.g., `10.2.0.2/32`)
3. **SERVER_COUNTRIES**: The country code for your ProtonVPN server (e.g., `US` for United States, `CA` for Canada)

Example extraction from a WireGuard config:
```ini
[Interface]
PrivateKey = ABC123... # Use this for WIREGUARD_PRIVATE_KEY
Address = 10.2.0.2/32 # Use this for WIREGUARD_ADDRESSES
```

## Additional gluetun Configuration

The gluetun container is configured with:
- VPN Service Provider: ProtonVPN
- VPN Type: WireGuard
- Port forwarding: 8080 (for qBittorrent WebUI)
- Network capabilities: NET_ADMIN (required for VPN)
- TUN device access (required for VPN)

## qBittorrent Container

The qBittorrent container:
- Uses the LinuxServer.io image
- Runs within gluetun's network namespace (all traffic goes through VPN)
- WebUI accessible on port 8080
- Volumes:
  - `/metalminds/qbittorrent/config`: qBittorrent configuration
  - `/metalminds/torrents/downloads`: Download directory

## Post-Setup Configuration

After deploying this configuration, you'll need to:

### 1. Configure qBittorrent Settings

On first login to qBittorrent WebUI (https://qbittorrent.harmony.silverlight-nex.us):
- Set up username and password
- Configure the following settings that were previously managed by NixOS:

#### BitTorrent Session Settings
- Default Save Path: `/downloads` (this maps to `/metalminds/torrents/downloads`)
- Ignore slow torrents for queueing: Enable
- Max active torrents: 999999999
- Max active uploads: 999999999
- Default torrent tags: `cross-seed`

#### WebUI Settings
- Enable "Use alternative Web UI" if needed
- Enable "Enable Host header validation"
- Set "Server domains" to: `qbittorrent.harmony.silverlight-nex.us`
- Enable "Use HTTPS"
- Enable "Use Reverse Proxy"

#### AutoRun Configuration for Cross-Seed
In qBittorrent Settings > Downloads > "Run external program on torrent finished":
```bash
curl -XPOST http://192.168.15.1:2468/api/webhook -H "@/path/to/cross-seed-headers-file" -d "infoHash=%I" -d "includeSingleEpisodes=true"
```

Note: You may need to install `curl` in the qBittorrent container or use the full path to curl.

### 2. Set Up Cross-Seed Integration

The cross-seed service is configured to connect to qBittorrent at `http://192.168.15.1:8080`. Ensure that:
- qBittorrent API is accessible
- Cross-seed has the correct API key configured in its settings file

### 3. Update API Keys

Update any API keys or authentication tokens in:
- Autobrr
- Radarr
- Sonarr
- Any other services that connect to qBittorrent

### 4. File Permissions

The qBittorrent container runs with PUID=1000 and PGID=1000. Ensure that:
- `/metalminds/qbittorrent/config` has appropriate permissions
- `/metalminds/torrents/downloads` has appropriate permissions
- The `qbittorrent` user (created in NixOS configuration) can access necessary files for cross-seed

## Testing VPN Connection

Once deployed, you can verify the VPN connection by:

```bash
# Check gluetun logs
docker logs gluetun

# Check qBittorrent logs
docker logs qbittorrent

# Verify IP address through gluetun
docker exec gluetun wget -qO- ifconfig.me
```

## Migration Notes

### What Changed:
1. **qBittorrent Service**: Migrated from NixOS service to Docker container
2. **VPN Method**: Changed from VPN-Confinement + WireGuard to gluetun
3. **Network Access**: qBittorrent now shares network namespace with gluetun
4. **Configuration**: Settings previously in `serverConfig` need to be set manually in WebUI

### What Stayed the Same:
1. **Port**: qBittorrent WebUI still on port 8080
2. **Network Access**: Still accessible via `192.168.15.1:8080`
3. **Nginx Proxy**: Unchanged (https://qbittorrent.harmony.silverlight-nex.us)
4. **Download Directory**: Still `/metalminds/torrents/downloads`
5. **Cross-seed Integration**: Still configured to work with qBittorrent

### Important Notes:
- The qBittorrent user and group are still created in NixOS for cross-seed compatibility
- Ensure the `gluetun.env.age` secret file is created before deploying
- Manual configuration in qBittorrent WebUI is required after first deployment

