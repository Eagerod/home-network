#!/usr/bin/env sh
#
# Kill pods with more restarts than the specified number.
#
set -euf

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

if [ $# -ne 1 ]; then
	echo >&2 "Usage:"
	echo >&2 "  $0 <n>"
	exit 1
fi

pod_template='{{range .items}}{{$name := .metadata.name}}{{range .status.containerStatuses}}{{$name}} {{.restartCount}}
{{end}}{{end}}'

slack 'Pod killer starting up on '"$(hostname)"'.
Killing pods with '"$1"' or more container restarts.'

while true; do
	kubectl get pods -n ${POD_KILLER_NAMESPACE} -o template="$pod_template" | awk '{for (i = 0; i < $2; i++) print $1}' | uniq -c | awk '$1 >= '"$1"' { print $2 }' | while read pod; do
		slack "Pod killer is killing \"${POD_KILLER_NAMESPACE}/$pod\""
		kubectl delete pod -n ${POD_KILLER_NAMESPACE} "$pod"
	done

	sleep 60
done
