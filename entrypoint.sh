#!/bin/bash

# Validate required environment variables
if [ -z "$API_TOKEN" ] || [ -z "$DOMAIN" ] || [ -z "$SUB_DOMAIN" ]; then
    echo "ERROR: Required environment variables missing"
    echo "Please set: API_TOKEN, DOMAIN, SUB_DOMAIN"
    echo "Optional: UPDATE_INTERVAL_MINUTES (default: 5)"
    exit 1
fi

# Set default interval if not provided
UPDATE_INTERVAL_MINUTES=${UPDATE_INTERVAL_MINUTES:-5}

echo "Starting Cloudflare DDNS service for ${SUB_DOMAIN}.${DOMAIN}"
echo "Update interval: $UPDATE_INTERVAL_MINUTES minutes"

# Function to handle graceful shutdown
shutdown_handler() {
    echo "Shutting down Cloudflare DDNS service..."
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap shutdown_handler SIGTERM SIGINT

# Run the script once immediately
echo "Running initial update..."
/usr/local/bin/cloudflare-ddns.sh 2>&1 | tee -a /var/log/cloudflare-ddns.log

# Main loop
while true; do
    echo "Waiting $UPDATE_INTERVAL_MINUTES minutes until next update..."
    sleep $((UPDATE_INTERVAL_MINUTES * 60))

    echo "Running scheduled update..."
    /usr/local/bin/cloudflare-ddns.sh 2>&1 | tee -a /var/log/cloudflare-ddns.log
done