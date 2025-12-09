#!/usr/bin/env bash
#
# List all failed jobs.
set -euf

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

FAILED_JOB_JSONPATH='{range .items[?(@.status.failed>0)]}{.metadata.name}{"\n"}{end}'

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

if [ $# -ne 1 ]; then
	echo >&2 "Usage:"
	echo >&2 "  $0 <namespace>"
	exit 1
fi

namespace="$1"

slack 'Failed job monitor running on "'"$(hostname)"'" for namespace "'"$namespace"'".'

while true; do
	echo >&2 "Run: $(date)"
	failed_jobs="$(kubectl -n "$namespace" get jobs -o "jsonpath=$FAILED_JOB_JSONPATH")"

	if [ -n "$failed_jobs" ]; then
		fj_indent="$(while read -r line; do printf '  %s\n' "$line"; done <<< "$failed_jobs")"
		fail_msg="$(printf 'Namespace "%s" has failed jobs:\n%s' "$namespace" "$fj_indent")"
		echo >&2 "$fail_msg"
		slack "$fail_msg"
	fi

	sleep 3600
done
