#!/usr/bin/env bash
#
# Update TXT records in Cloudflare for certbot renewals.
#
set -euf

# Certbot envs
: "${CERTBOT_DOMAIN:?CERTBOT_DOMAIN must be passed in from certbot}"
: "${CERTBOT_VALIDATION:?CERTBOT_VALIDATION must be passed in from certbot}"

# Cloudflare envs
: "${CF_API_TOKEN:?CF_API_TOKEN is required}"
: "${CF_ZONE_ID:?CF_ZONE_ID is required}"

ACTUAL_DOMAIN="_acme-challenge.$CERTBOT_DOMAIN"

# Cloudflare UI automatically adds quotes, but API doesn't.
# Explicitly quote the TXT record value.
CF_PAYLOAD="$(jq -nc --arg name "$ACTUAL_DOMAIN" --arg content "\"$CERTBOT_VALIDATION\"" \
    '{type: "TXT", name: $name, content: $content}')"

# Get existing record ID (if any)
echo >&2 "Fetching existing TXT record for ${ACTUAL_DOMAIN}..."
RESPONSE="$(curl -s -X GET \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=TXT&name=${ACTUAL_DOMAIN}")"

if RECORD_ID="$(jq -r '.result[0].id' <<< "$RESPONSE")"; then
    echo >&2 "Existing record found (ID: ${RECORD_ID}), updating it..."
    RESPONSE="$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${RECORD_ID}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$CF_PAYLOAD")"
else
    # Probably won't work with the API Key that I have.
    echo >&2 "No existing record found, creating a new one..."
    RESPONSE="$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$CF_PAYLOAD")"
fi

if jq -e '.success' <<< "$RESPONSE" >/dev/null; then
    echo >&2 "TXT record updated successfully."
else
    echo >&2 "Failed to update TXT record. Response follows..."
    echo >&2 "$RESPONSE"
    exit 1
fi

echo >&2 "Cloudflare's auto TTL is 300 seconds. Waiting 300 seconds..."
sleep 300
