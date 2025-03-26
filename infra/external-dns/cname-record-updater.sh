#!/usr/bin/env bash
#
set -eufo pipefail

ACTUAL_DOMAIN="aleemhaji.com"

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

# Cloudflare envs
: "${CF_API_TOKEN:?CF_API_TOKEN is required}"
: "${CF_ZONE_ID:?CF_ZONE_ID is required}"

# Ingress envs
: "${INGRESS_CLASS:?INGRESS_CLASS is required}"
: "${CNAME_TARGET:?CNAME_TARGET is required}"

slack() {
	if ! curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"; then
        echo >&2 "Failed to send message to Slack: $*"
    fi
}

get_record() {
	record_found="$(sqlite3 "$dbfile" "SELECT 1 FROM records WHERE domain = '$1';")"
	if [ "$record_found" = "1" ]; then
		sqlite3 "$dbfile" "SELECT response FROM records WHERE domain = '$1';"
		return
	fi

	echo >&2 "Fetching existing CNAME record for $1..."
	response="$(curl -s -X GET \
		-H "Authorization: Bearer ${CF_API_TOKEN}" \
		"https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=CNAME&name=$1")"

	sqlite3 "$dbfile" "INSERT INTO records VALUES ('$1', '$response');"
	echo "$response"
}

ensure_record() {
	record="$(get_record "$1" | jq -r '.result[0] | "\(.id) \(.content)"')"
    read -r record_id target <<< "$record"
	
	# If anything needs to be written
	cf_payload="$(jq -nc --arg name "$1" --arg content "$CNAME_TARGET" \
		'{type: "CNAME", name: $name, content: $content}')"

	if [ "$record_id" = "null" ]; then
		slack "Creating new CNAME record for $1 -> $CNAME_TARGET"
		curl -sS -o /dev/null -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
			-H "Authorization: Bearer ${CF_API_TOKEN}" \
			-H "Content-Type: application/json" \
			--data "$cf_payload"
		return 0
	fi

	if [ "$target" = "$CNAME_TARGET" ]; then
		echo >&2 "Record for $1 already correct"
	else
		slack "Updating CNAME record for $1 -> $CNAME_TARGET ($record_id)"
		curl -sS -o /dev/null -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${record_id}" \
			-H "Authorization: Bearer ${CF_API_TOKEN}" \
			-H "Content-Type: application/json" \
			--data "$cf_payload"

		sqlite3 "$dbfile" "DELETE FROM records WHERE domain = '$1';"
	fi
}

delete_record() {
	record_id="$(get_record "$1" | jq -r '.result[0] | "\(.id)"')"

	if [ -z "$record_id" ]; then
		echo >&2 "Failed to find record for $1 to delete"
		return
	fi

	slack "Deleting CNAME record for $1"
	curl -sS -o /dev/null -X DELETE "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${record_id}" \
		-H "Authorization: Bearer ${CF_API_TOKEN}"
	
	sqlite3 "$dbfile" "DELETE FROM records WHERE domain = '$1';"
}

resource_update() {
    read -r namespace ingress domain event <<< "$@"

	if [ "$event" = "DELETED" ]; then
		echo >&2 "Deleting $domain for $namespace/$ingress"
		delete_record "$domain"
	else
		echo >&2 "Ensuring $domain exists for $namespace/$ingress"
		ensure_record "$domain"
	fi
}

# The whole sqlite wrapper for records might be a bit overkill for now
dbfile="$(mktemp)"
trap 'rm -f "$dbfile"' EXIT

sqlite3 "$dbfile" 'CREATE TABLE records (domain TEXT PRIMARY KEY, response TEXT);'

kubectl get ingress --output-watch-events -A -w -o custom-columns="NAMESPACE:.object.metadata.namespace,NAME:.object.metadata.name,INGRESS_CLASS:.object.spec.ingressClassName,HOSTS:.object.spec.rules[*].host,EVENT:.type" | \
  awk "{ if (\$3 == \"$INGRESS_CLASS\") print; fflush()}" | \
  awk "{ if (\$4 != \"$CNAME_TARGET\") print; fflush()}" | \
  awk '{ print $1, $2, $4, $5; fflush() }' | \
  while read -r line; do
	resource_update "$line"
  done

echo "Watch exited, dumping records..."
sqlite3 "$dbfile" 'SELECT * FROM records;'
