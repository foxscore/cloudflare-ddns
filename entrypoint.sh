#!/bin/bash

# Validate required environment variables
if [ -z "$API_TOKEN" ] || [ -z "$DOMAIN" ] || [ -z "$SUB_DOMAIN" ]; then
    echo "ERROR: Required environment variables missing"
    echo "Please set: API_TOKEN, DOMAIN, SUB_DOMAIN"
    echo "Optional: CRON_SCHEDULE (default: */5 * * * *)"
    exit 1
fi

echo "Starting Cloudflare DDNS service for ${SUB_DOMAIN}.${DOMAIN}"
echo "Cron schedule: $CRON_SCHEDULE"

# Create crontab entry
echo "$CRON_SCHEDULE /usr/local/bin/cloudflare-ddns.sh 2>&1 | tee -a /var/log/cloudflare-ddns.log" > /var/spool/cron/crontabs/root
chmod 600 /var/spool/cron/crontabs/root

# Run the script once immediately
echo "Running initial update..."
/usr/local/bin/cloudflare-ddns.sh

# Start crond in the foreground
echo "Starting cron daemon..."
exec crond -f -d 0