#!/usr/bin/env bash
#
# Monitor the output of a shell script, and if the value ever changes, send a
#   message via. Slack to notify of the change.
set -eufo pipefail

TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

DATA_KEY=value
PARENT_RESOURCE="https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/${SHELL_MONITOR_NAMESPACE}/configmaps"
FULL_RESOURCE="$PARENT_RESOURCE/$CONFIG_MAP_NAME"
RESOURCE_PATH="${SHELL_MONITOR_NAMESPACE}/$CONFIG_MAP_NAME"

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

get_value() {
	curl -fsS -H "Authorization: Bearer $TOKEN" --insecure "$FULL_RESOURCE" | jq -r ".data.$DATA_KEY"
}

set_value() {
	curl -fsS -XPATCH -H "Content-Type: application/merge-patch+json" -H "Authorization: Bearer $TOKEN" -d '{
		"data": {
			"'"$DATA_KEY"'": "'"${1:1:-1}"'"
		}
	}' --insecure "$FULL_RESOURCE" > /dev/null
}

# Eats the trailing newling.
# Can't really explain why, but it does what I want.
strip_trailing_newline() {
	printf "%s" "$(cat -)"
}

# If the container this script is running in is missing required programs,
#   error out in whatever way makes sense given which programs are missing.
if ! type curl; then
	# In this case, can't even post to Slack, so log and exit with error.
	# Let the crash loop notify that something is wrong.
	echo >&2 "Curl not installed."
	exit 1
elif ! type jq; then
	slack "Monitor for $RESOURCE_PATH running in invalid container; must have jq installed."
	sleep infinity
fi

# Check to see if the ConfigMap already exists.
# If not, create it.
set +e
current_value="$(get_value | strip_trailing_newline | jq -R -s '.')"
ec="$?"
set -e

if [ "$ec" -ne 0 ]; then
	curl -fsS -XPOST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{
		"kind": "ConfigMap",
		"apiVersion": "v1",
		"metadata": {
			"name": "'"$CONFIG_MAP_NAME"'"
		}
	}' --insecure "$PARENT_RESOURCE"
	slack "Monitor for $RESOURCE_PATH created new ConfigMap."
else
	echo >&2 "Script starting up watching $RESOURCE_PATH."
	echo >&2 "Skipping notification to avoid noise."
fi

while true; do
	new_value="$($UPDATE_SCRIPT | strip_trailing_newline | jq -R -s '.')"

	if [ "$new_value" != "$current_value" ]; then
		set_value "$new_value"
		current_value="$new_value"

		if [ -z "$current_value" ]; then
			slack "Monitor cleared value of $RESOURCE_PATH"
		else
			slack "Monitor changed value of $RESOURCE_PATH to: $(echo "$current_value" | jq -r '.')"
		fi
	fi

	sleep "$UPDATE_INTERVAL"
done