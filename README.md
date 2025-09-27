# Cloudflare DDNS Docker

A containerized Cloudflare Dynamic DNS updater that automatically fetches zone IDs and runs as a cron job.

## Environment Variables

- `API_TOKEN` (required): Your Cloudflare API token
- `DOMAIN` (required): Your domain (e.g., `example.com`)
- `SUB_DOMAIN` (required): Your subdomain(s). Can be a single subdomain (e.g., `home`) or multiple subdomains separated by semicolons (e.g., `home;vpn;api`)
- `CRON_SCHEDULE` (optional): Cron schedule, default is `*/5 * * * *` (every 5 minutes)
- `TZ` (optional): Timezone, default is `UTC`

## Usage

### Single Subdomain
```bash
docker build -t cloudflare-ddns .
docker run -d \
  --cap-add=SYS_TIME \
  -e API_TOKEN=your_token_here \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN=home \
  cloudflare-ddns
```

### Multiple Subdomains
```bash
docker run -d \
  --cap-add=SYS_TIME \
  -e API_TOKEN=your_token_here \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN="home;vpn;api;server" \
  cloudflare-ddns
```

### Docker Compose
```bash
# Edit docker-compose.yml with your values
docker-compose up -d
```

## Important Notes

### Required Capability
The container requires the `SYS_TIME` capability for the cron daemon to function properly. This capability is included in the provided docker-compose.yml file and the examples above. Without this capability, you may see errors like "setpgid: Operation not permitted".

## Features

- Automatically fetches and caches Cloudflare zone ID
- Supports multiple subdomains in a single container
- Preserves existing DNS record settings (TTL, proxy status)
- Runs as a cron job with configurable schedule
- Logs all operations with timestamps
- No persistent volumes needed (cache stored in container)
- Tracks success/failure for each subdomain individually