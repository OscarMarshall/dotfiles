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

1. Configure qBittorrent username/password on first login
2. Set up the AutoRun script for cross-seed integration in qBittorrent settings
3. Update any API keys or authentication tokens in other services that connect to qBittorrent

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
