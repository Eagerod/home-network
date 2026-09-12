#!/usr/bin/env sh
#
# Delete jobs that appear to be CronJobs that have been run manually from the
#   Kubernetes Dashboard.
set -euf

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

if [ $# -ne 2 ]; then
	echo >&2 "Usage:"
	echo >&2 "  $0 <namespace> <age>"
	exit 1
fi

namespace="$1"
age_str="$2"

MANUAL_JOB_REGEXP='-manual-[[:alnum:]]\{3,5\}[[:space:]]'
JOBS_COLUMNS='custom-columns=NAME:{.metadata.name},SUCCEEDED:{.status.succeeded},COMPLETED:{.status.completionTime}'

# shellcheck disable=SC2016
AWK_SCRIPT='{if ($2 == 1 && $3 < arg) print $1}'

slack 'Manual job-run cleanup running on '"$(hostname)"'.
Deleting successful manually run jobs in namespace "'"$namespace"'" older than '"$age_str"'.'

while true; do
    one_month_ago="$(date -u -d "$age_str ago" '+%Y-%m-%dT%H:%M:%SZ')"
	echo "Run: $(date) -> $one_month_ago"
	kubectl -n "$namespace" get jobs -o "$JOBS_COLUMNS" | sed '1d' | grep -- "$MANUAL_JOB_REGEXP" | awk -v "arg=$one_month_ago" "$AWK_SCRIPT" | while read -r job; do
		slack "Job monitor deleting old manually run job: $namespace/$job"
		kubectl -n "${namespace}" delete job "$job"
	done

	sleep 3600
done
