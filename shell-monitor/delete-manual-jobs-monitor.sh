#!/usr/bin/env sh
#
# Delete jobs that appear to be CronJobs that have been run manually from the
#   Kubernetes Dashboard.
set -euf

MANUAL_JOB_REGEXP='-manual-[[:alnum:]]\{3\}[[:space:]]'
ONE_MONTH_AGO="$(date -u -d '1 month ago' '+%Y-%m-%dT%H:%M:%SZ')"
KUBE_NAMESPACE="${KUBE_NAMESPACE}"

# Newline to start the monitored output.
echo ""

kubectl -n "$KUBE_NAMESPACE" get jobs -o custom-columns="NAME:{.metadata.name},SUCCEEDED:{.status.succeeded},COMPLETED:{.status.completionTime}" | \
	sed '1d' |\
    grep -- "$MANUAL_JOB_REGEXP" |\
	awk '{if ($2 == 1) print}' |\
	awk -v "arg=$ONE_MONTH_AGO" '{if ($3 < arg) print $1}' |\
	while read job; do
	echo "Kubernetes job monitor deleting old manually run job: $job"
	kubectl -n "${KUBE_NAMESPACE}" delete job "$job"
done
