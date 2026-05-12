# XDC Docker

Docker deployment for an [XDC Network](https://xdc.network/) Mainnet RPC node.

- **Network:** XDC Mainnet
- **Chain ID:** `50` (`0x32`)
- **RPC mode:** Full node with optional snapshot bootstrap

This is xdc-docker v1.0.0

## Quick Start

```bash
# Clone and enter directory
git clone https://github.com/CryptoManufaktur-io/xdc-docker.git
cd xdc-docker

# Configure
cp default.env .env
vim .env   # Set SNAPSHOT_URL for faster sync (optional)
           # Set DOMAIN, RPC_HOST for Traefik

# Start the node
./xdcd up

# Tail logs
./xdcd logs -f xdc

# Check sync status
./xdcd check_sync
```

### With Snapshot (Recommended)

For faster sync, enable snapshot in `.env`:
```bash
SNAPSHOT_URL=https://download.xinfin.network/xdcchain.tar
```

Sync time: ~12-24 hours with snapshot vs. 3-4 days from genesis.

## Prerequisites

- Docker Engine 23+ with Compose V2
- Git
- **Disk Space:** 1.5+ TB free (800GB data + 650GB snapshot during extraction)

```bash
# Install Docker (Debian/Ubuntu)
./xdcd install
```

## Command Reference

| Command | Description |
|---------|-------------|
| `./xdcd up` | Start the node |
| `./xdcd down` | Stop the node |
| `./xdcd restart` | Restart the node |
| `./xdcd logs -f xdc` | Follow logs |
| `./xdcd update` | Update images and configuration |
| `./xdcd check_sync` | Check sync status |
| `./xdcd version` | Show client versions |
| `./xdcd space` | Show disk space usage |
| `./xdcd terminate` | Stop and delete all data (destructive!) |
| `./xdcd help` | Show full help |

## Configuration

Edit `.env` to customize your deployment. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `COMPOSE_FILE` | Compose files to use (colon-separated) | `xdc.yml` |
| `NETWORK` | Network (mainnet/testnet, auto-derives network ID) | `mainnet` |
| `NODE_DOCKER_TAG` | Docker image tag | `v2.7.0` |
| `GENESIS_URL` | Genesis JSON URL | XinFin mainnet genesis |
| `SNAPSHOT_URL` | Snapshot URL for faster sync | (empty = sync from genesis) |
| `XDC_BOOTNODES` | Comma-separated enode URLs | XDC mainnet bootnodes |
| `SYNC_MODE` | Sync mode (full/snap/fast) | `full` |
| `GC_MODE` | Garbage collection (full/archive) | `full` |
| `P2P_PORT` | P2P port | `30303` |
| `RPC_PORT` | HTTP RPC port | `8545` |
| `WS_PORT` | WebSocket port | `8546` |

### Compose File Overlays

Add overlays to `COMPOSE_FILE` in `.env`:

```bash
# Expose RPC ports locally
COMPOSE_FILE=xdc.yml:rpc-shared.yml

# Connect to external Traefik network
COMPOSE_FILE=xdc.yml:ext-network.yml

# Both
COMPOSE_FILE=xdc.yml:rpc-shared.yml:ext-network.yml
```

### Traefik Integration

For secure web proxy with Traefik:

1. Add `:ext-network.yml` to `COMPOSE_FILE`
2. Configure in `.env`:
   ```bash
   DOCKER_EXT_NETWORK=traefik_default
   DOMAIN=example.com
   RPC_HOST=xdc
   WS_HOST=xdcws
   ```

**Important:** Always configure Traefik middleware (IP allowlisting, authentication) in your Traefik dynamic configuration. Never expose RPC publicly without protection.

### Testnet

For testnet, use the provided configuration:
```bash
cp .env.testnet .env
./xdcd up
```

Network ID is auto-derived (mainnet=50, testnet=51).

## Data Storage

Node data is stored in a Docker named volume (`xdc-docker_xdc-data`). Check usage with `./xdcd space` or `docker volume ls`.

## Troubleshooting

### Check Disk Space
```bash
./xdcd space
docker system df
```

### Slow Sync
- Check peer count in logs: `./xdcd logs -f xdc | grep peer`
- Bootnodes are auto-configured in `XDC_BOOTNODES`
- Node may take 10-15 minutes to discover peers initially

## Links

- [XDC Block Explorer](https://xdcscan.com/)
- [XDC Node Stats](http://stats.xinfin.network/)
- [XDC GitHub](https://github.com/XinFinOrg/XinFin-Node/)
- [XDC Documentation](https://docs.xdc.network/)

## License

Apache 2.0 - See [LICENSE](LICENSE)
