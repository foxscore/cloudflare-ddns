# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a containerized Cloudflare Dynamic DNS updater that runs as a Docker container with cron scheduling. The application automatically updates DNS A records for specified subdomains when the public IP address changes.

## Architecture

- **Dockerfile**: Alpine Linux-based container with bash, curl, jq, and dcron
- **script.sh**: Main DNS update logic that handles multiple subdomains
- **entrypoint.sh**: Container initialization and cron setup
- **docker-compose.yml**: Service orchestration with environment configuration

## Key Components

### DNS Update Flow
1. Cache zone ID in `/tmp/zone_cache.txt` to avoid repeated API calls
2. Fetch current public IP from `https://ipv4.icanhazip.com/`
3. Compare with existing DNS record IP
4. Update record via Cloudflare API if changed, preserving TTL and proxy settings
5. Process multiple subdomains (separated by semicolons) independently

### Environment Variables
- `API_TOKEN` (required): Cloudflare API token
- `DOMAIN` (required): Root domain (e.g., `example.com`)
- `SUB_DOMAIN` (required): Single subdomain or multiple separated by semicolons
- `CRON_SCHEDULE` (optional): Default `*/5 * * * *` (every 5 minutes)
- `TZ` (optional): Timezone, default `UTC`

## Common Commands

### Local Development
```bash
# Build Docker image
docker build -t cloudflare-ddns .

# Run single subdomain
docker run -d \
  -e API_TOKEN=your_token \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN=home \
  cloudflare-ddns

# Run multiple subdomains
docker run -d \
  -e API_TOKEN=your_token \
  -e DOMAIN=example.com \
  -e SUB_DOMAIN="home;vpn;api" \
  cloudflare-ddns
```

### Docker Compose
```bash
# Start service
docker-compose up -d

# View logs
docker-compose logs -f

# Stop service
docker-compose down
```

### Testing
```bash
# Test script directly (requires environment variables)
bash script.sh

# View container logs
docker logs [container_id]

# Check cron job
docker exec [container_id] crontab -l
```

## Build and Deployment

The project uses GitHub Actions for automated Docker image builds:
- Manual workflow dispatch with configurable tags
- Multi-platform builds (linux/amd64, linux/arm64)
- Publishes to GitHub Container Registry
- Supports both custom tags and latest

## Important Behaviors

- **DNS Record Management**: Only updates existing records, will not create new ones
- **Error Handling**: Continues processing other subdomains if one fails
- **Caching**: Zone ID is cached to reduce API calls
- **Preservation**: Maintains existing TTL and proxy status when updating records
- **Logging**: All operations logged with timestamps to `/var/log/cloudflare-ddns.log`