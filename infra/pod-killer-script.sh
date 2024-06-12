#!/usr/bin/env sh
#
# Kill pods with more restarts than the specified number.
#
set -euf

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

if [ $# -ne 2 ]; then
	echo >&2 "Usage:"
	echo >&2 "  $0 <namespace> <n_restarts>"
	exit 1
fi

namespace="$1"
n_restarts="$2"
# shellcheck disable=SC2016
pod_template='{{range .items}}{{$name := .metadata.name}}{{range .status.containerStatuses}}{{$name}} {{.restartCount}}
{{end}}{{end}}'

slack 'Pod killer starting up on '"$(hostname)"'.
Killing pods in namespace "'"$namespace"'" with '"$n_restarts"' or more container restarts.'

while true; do
	echo "Run: $(date)"
	kubectl get pods -n "${namespace}" -o template="$pod_template" | awk '{for (i = 0; i < $2; i++) print $1}' | uniq -c | awk '$1 >= '"$n_restarts"' { print $2 }' | while read -r pod; do
		slack "Pod killer is killing \"${namespace}/$pod\""
		kubectl delete pod -n "${namespace}" "$pod"
	done

	sleep 60
done
