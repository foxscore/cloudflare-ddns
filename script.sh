#!/bin/bash

# Environment variables (required)
if [ -z "$API_TOKEN" ] || [ -z "$DOMAIN" ] || [ -z "$SUB_DOMAIN" ]; then
    echo "$(date): ERROR: Required environment variables missing"
    echo "Please set: API_TOKEN, DOMAIN, SUB_DOMAIN"
    echo "SUB_DOMAIN can contain multiple subdomains separated by semicolons (;)"
    echo "Optional: SYNC_SPF=true to enable SPF record synchronization"
    echo "Optional: SPF_RECORD_NAME (defaults to root domain)"
    exit 1
fi

# SPF synchronization defaults
SYNC_SPF=${SYNC_SPF:-false}
SPF_RECORD_NAME=${SPF_RECORD_NAME:-$DOMAIN}

ZONE_CACHE_FILE="/tmp/zone_cache.txt"

# Function to get zone ID from cache or API
get_zone_id() {
    if [ -f "$ZONE_CACHE_FILE" ]; then
        CACHED_ZONE_ID=$(cat "$ZONE_CACHE_FILE")
        if [ -n "$CACHED_ZONE_ID" ] && [ "$CACHED_ZONE_ID" != "null" ]; then
            echo "$CACHED_ZONE_ID"
            return 0
        fi
    fi

    echo "$(date): Fetching zone ID for domain $DOMAIN" >&2
    ZONE_DATA=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    ZONE_ID=$(echo $ZONE_DATA | jq -r '.result[0].id // empty')

    if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
        echo "$(date): ERROR: Could not find zone for domain $DOMAIN" >&2
        exit 1
    fi

    # Cache the zone ID
    echo "$ZONE_ID" > "$ZONE_CACHE_FILE"
    echo "$ZONE_ID"
}

# Function to update a single DNS record
update_dns_record() {
    local SUBDOMAIN="$1"
    local RECORD_NAME="${SUBDOMAIN}.${DOMAIN}"

    echo "$(date): Processing $RECORD_NAME"

    # Get current DNS record
    RECORD_DATA=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME&type=A" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    # Check if API call was successful
    API_SUCCESS=$(echo $RECORD_DATA | jq -r '.success // false')
    if [ "$API_SUCCESS" != "true" ]; then
        echo "$(date): ERROR: API call failed for $RECORD_NAME"
        echo "$(date): Response: $RECORD_DATA"
        return 1
    fi

    # Check if we have any results
    RESULT_COUNT=$(echo $RECORD_DATA | jq -r '.result | length')
    if [ "$RESULT_COUNT" = "0" ]; then
        echo "$(date): ERROR: DNS record '$RECORD_NAME' does not exist. Please create it manually in Cloudflare first."
        return 1
    fi

    RECORD_IP=$(echo $RECORD_DATA | jq -r '.result[0].content // empty')
    RECORD_ID=$(echo $RECORD_DATA | jq -r '.result[0].id // empty')
    RECORD_PROXIED=$(echo $RECORD_DATA | jq -r '.result[0].proxied // false')
    RECORD_TTL=$(echo $RECORD_DATA | jq -r '.result[0].ttl // 300')

    # Check if IP has changed
    if [ "$CURRENT_IP" != "$RECORD_IP" ]; then
        echo "$(date): $RECORD_NAME IP changed from $RECORD_IP to $CURRENT_IP"

        # Update existing record while preserving proxy status and TTL
        echo "$(date): Updating $RECORD_NAME (proxied: $RECORD_PROXIED, TTL: $RECORD_TTL)"
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":$RECORD_TTL,\"proxied\":$RECORD_PROXIED}")

        # Check if the API call was successful
        SUCCESS=$(echo $RESPONSE | jq -r '.success')
        if [ "$SUCCESS" = "true" ]; then
            echo "$(date): $RECORD_NAME updated successfully"
            return 0
        else
            echo "$(date): Failed to update $RECORD_NAME"
            echo "$(date): Response: $RESPONSE"
            return 1
        fi
    else
        echo "$(date): $RECORD_NAME IP unchanged: $CURRENT_IP (proxied: $RECORD_PROXIED)"
        return 0
    fi
}

# Function to synchronize SPF record with current IP
sync_spf_record() {
    if [ "$SYNC_SPF" != "true" ]; then
        return 0
    fi

    echo "$(date): Checking SPF record for $SPF_RECORD_NAME"

    # Get current SPF record
    SPF_DATA=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$SPF_RECORD_NAME&type=TXT" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    # Check if API call was successful
    API_SUCCESS=$(echo $SPF_DATA | jq -r '.success // false')
    if [ "$API_SUCCESS" != "true" ]; then
        echo "$(date): ERROR: SPF API call failed for $SPF_RECORD_NAME"
        echo "$(date): Response: $SPF_DATA"
        return 1
    fi

    # Find SPF record among TXT records
    SPF_RECORD=$(echo $SPF_DATA | jq -r '.result[] | select(.content | startswith("v=spf1")) | {id: .id, content: .content, ttl: .ttl, proxied: .proxied}')
    
    if [ -z "$SPF_RECORD" ]; then
        echo "$(date): No SPF record found for $SPF_RECORD_NAME. Skipping SPF sync."
        return 0
    fi

    # Check for multiple SPF records (RFC 7208 violation)
    SPF_COUNT=$(echo $SPF_DATA | jq -r '[.result[] | select(.content | startswith("v=spf1"))] | length')
    if [ "$SPF_COUNT" -gt 1 ]; then
        echo "$(date): WARNING: Multiple SPF records found ($SPF_COUNT). RFC 7208 states only one SPF record should exist. Processing first record only."
    fi

    SPF_RECORD_ID=$(echo $SPF_RECORD | jq -r '.id')
    SPF_CONTENT=$(echo $SPF_RECORD | jq -r '.content')
    SPF_TTL=$(echo $SPF_RECORD | jq -r '.ttl // 300')
    SPF_PROXIED=$(echo $SPF_RECORD | jq -r '.proxied // false')

    echo "$(date): Current SPF record: $SPF_CONTENT"

    # Check if SPF contains any ip4 mechanism
    if ! echo "$SPF_CONTENT" | grep -q "ip4:"; then
        echo "$(date): SPF record does not contain ip4 mechanism. Skipping SPF sync."
        return 0
    fi

    # Replace all ip4: mechanisms with current IP
    # This regex replaces ip4:x.x.x.x or ip4:x.x.x.x/xx with ip4:$CURRENT_IP
    # More restrictive pattern to match valid IPv4 addresses (0-255 for each octet)
    NEW_SPF_CONTENT=$(echo "$SPF_CONTENT" | sed -E "s/ip4:([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]+)?/ip4:$CURRENT_IP/g")

    # Check if SPF content changed
    if [ "$SPF_CONTENT" = "$NEW_SPF_CONTENT" ]; then
        echo "$(date): SPF record already up to date"
        return 0
    fi

    echo "$(date): SPF record needs update"
    echo "$(date): Old: $SPF_CONTENT"
    echo "$(date): New: $NEW_SPF_CONTENT"

    # Update SPF record
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$SPF_RECORD_ID" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"TXT\",\"name\":\"$SPF_RECORD_NAME\",\"content\":\"$NEW_SPF_CONTENT\",\"ttl\":$SPF_TTL,\"proxied\":$SPF_PROXIED}")

    # Check if the API call was successful
    SUCCESS=$(echo $RESPONSE | jq -r '.success')
    if [ "$SUCCESS" = "true" ]; then
        echo "$(date): SPF record updated successfully"
        return 0
    else
        echo "$(date): Failed to update SPF record"
        echo "$(date): Response: $RESPONSE"
        return 1
    fi
}

# Get zone ID (from cache or API)
ZONE_ID=$(get_zone_id)

# Get current public IP
CURRENT_IP=$(curl -s https://ipv4.icanhazip.com/)

if [ -z "$CURRENT_IP" ]; then
    echo "$(date): Failed to get current IP"
    exit 1
fi

echo "$(date): Current public IP: $CURRENT_IP"

# Split SUB_DOMAIN by semicolon and process each subdomain
IFS=';' read -ra SUBDOMAINS <<< "$SUB_DOMAIN"
FAILED_UPDATES=0
TOTAL_UPDATES=0

for SUBDOMAIN in "${SUBDOMAINS[@]}"; do
    # Trim whitespace
    SUBDOMAIN=$(echo "$SUBDOMAIN" | tr -d ' ')

    if [ -n "$SUBDOMAIN" ]; then
        TOTAL_UPDATES=$((TOTAL_UPDATES + 1))
        if ! update_dns_record "$SUBDOMAIN"; then
            FAILED_UPDATES=$((FAILED_UPDATES + 1))
        fi
    fi
done

echo "$(date): Processed $TOTAL_UPDATES subdomains, $FAILED_UPDATES failed"

# Synchronize SPF record if enabled
if [ "$SYNC_SPF" = "true" ]; then
    if ! sync_spf_record; then
        echo "$(date): SPF synchronization failed"
        exit 1
    fi
fi

if [ $FAILED_UPDATES -gt 0 ]; then
    exit 1
fi
