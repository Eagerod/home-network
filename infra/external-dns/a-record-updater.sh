#!/usr/bin/env bash
#
# Update the Cloudflare A record.
# Steals a lot from the certbot TXT record updater; might be worth
#   consolidating some of these together.
set -euf

ACTUAL_DOMAIN="aleemhaji.com"

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

# Cloudflare envs
: "${CF_API_TOKEN:?CF_API_TOKEN is required}"
: "${CF_ZONE_ID:?CF_ZONE_ID is required}"

slack() {
	if ! curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"; then
        echo >&2 "Failed to send message to Slack: $*"
    fi
}

echo >&2 "Fetching existing A record for ${ACTUAL_DOMAIN}..."
response="$(curl -s -X GET \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${ACTUAL_DOMAIN}")"

echo "$response"
if ! record_id="$(jq -er '.result[0].id' <<< "$response")"; then
	slack "Failed to find an A record for $ACTUAL_DOMAIN from Cloudflare"
	exit 1
fi

echo >&2 "Existing record found (ID: ${record_id}), updating it..."
if ! external_ip="$(curl -fsS https://icanhazip.com)"; then
	slack "Failed to find WAN IP from $(hostname) for A record update."
	exit 2
fi

if [ "$(jq -er '.result[0].content' <<< "$response")" = "$external_ip" ]; then
	echo >&2 "A record already holds the expected value. Exiting early"
	exit 0
fi

slack "Updating A record to $external_ip"
cf_payload="$(jq -nc --arg name "$ACTUAL_DOMAIN" --arg content "$external_ip" \
    '{type: "A", name: $name, content: $content}')"

response="$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${record_id}" \
	-H "Authorization: Bearer ${CF_API_TOKEN}" \
	-H "Content-Type: application/json" \
	--data "$cf_payload")"
