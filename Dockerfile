FROM alpine:3.18

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    dcron \
    tzdata

# Copy the script
COPY script.sh /usr/local/bin/cloudflare-ddns.sh
RUN chmod +x /usr/local/bin/cloudflare-ddns.sh

# Create cron directory and set proper permissions
RUN mkdir -p /var/spool/cron/crontabs && \
    chmod 600 /var/spool/cron/crontabs

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create log directory
RUN mkdir -p /var/log

# Set environment variables with defaults
ENV CRON_SCHEDULE="*/5 * * * *"
ENV TZ=UTC

ENTRYPOINT ["/entrypoint.sh"]