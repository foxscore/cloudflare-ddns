# Cloudflare DDNS Docker

A containerized Cloudflare Dynamic DNS updater that automatically fetches zone IDs and runs with periodic updates.

## Environment Variables

- `API_TOKEN` (required): Your Cloudflare API token
- `DOMAIN` (required): Your domain (e.g., `example.com`)
- `SUB_DOMAIN` (required): Your subdomain(s). Can be a single subdomain (e.g., `home`) or multiple subdomains separated by semicolons (e.g., `home;vpn;api`)
- `UPDATE_INTERVAL_MINUTES` (optional): Update interval in minutes, default is `5`
- `TZ` (optional): Timezone, default is `UTC`
- `SYNC_SPF` (optional): Set to `true` to enable SPF record synchronization, default is `false`
- `SPF_RECORD_NAME` (optional): Domain name for SPF record, default is the root domain (`$DOMAIN`)

## Usage

### Single Subdomain
```bash
docker run -d \
  -e API_TOKEN=your_token_here \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN=home \
  ghcr.io/foxscore/cloudflare-ddns:latest
```

### Multiple Subdomains
```bash
docker run -d \
  -e API_TOKEN=your_token_here \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN="home;vpn;api;server" \
  ghcr.io/foxscore/cloudflare-ddns:latest
```

### Custom Update Interval
```bash
docker run -d \
  -e API_TOKEN=your_token_here \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN=home \
  -e UPDATE_INTERVAL_MINUTES=10 \
  ghcr.io/foxscore/cloudflare-ddns:latest
```

### Docker Compose
```bash
# Edit docker-compose.yml with your values
docker-compose up -d
```

### With SPF Record Synchronization
```bash
docker run -d \
  -e API_TOKEN=your_token_here \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN=home \
  -e SYNC_SPF=true \
  ghcr.io/foxscore/cloudflare-ddns:latest
```

This will automatically update any `ip4:` mechanisms in your SPF record when your IP changes.

### Custom SPF Record Name
```bash
docker run -d \
  -e API_TOKEN=your_token_here \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN=home \
  -e SYNC_SPF=true \
  -e SPF_RECORD_NAME=mail.example.com \
  ghcr.io/foxscore/cloudflare-ddns:latest
```

## Building from Source

If you prefer to build the image yourself instead of using the pre-built image:

```bash
docker build -t cloudflare-ddns .
# Then use cloudflare-ddns instead of ghcr.io/foxscore/cloudflare-ddns:latest
```

## Features

- Automatically fetches and caches Cloudflare zone ID
- Supports multiple subdomains in a single container
- Preserves existing DNS record settings (TTL, proxy status)
- Runs with configurable update intervals
- Logs all operations with timestamps
- No persistent volumes needed (cache stored in container)
- Tracks success/failure for each subdomain individually
- Optional SPF record synchronization to keep `ip4:` mechanisms updated