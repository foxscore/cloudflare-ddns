FROM alpine:3.18

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    tzdata

# Copy the script
COPY script.sh /usr/local/bin/cloudflare-ddns.sh
RUN chmod +x /usr/local/bin/cloudflare-ddns.sh


# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create log directory
RUN mkdir -p /var/log

# Set environment variables with defaults
ENV UPDATE_INTERVAL_MINUTES=5
ENV TZ=UTC

ENTRYPOINT ["/entrypoint.sh"]