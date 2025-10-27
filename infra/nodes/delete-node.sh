#!/usr/bin/env sh
#
# Remove a node from the cluster.
#
set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLACK="${SCRIPT_DIR}/slack.sh"

if [ $# -ne 1 ]; then
	echo >&2 "usage: $0 <node-name>"
	exit 1
fi

node_id="$1"

if hope --config hope.yaml node status "$node_id" 2> /dev/null; then
	"${SLACK}" "Node rotator removing node from Kubernetes cluster ($node_id)..."
	hope --config hope.yaml node reset --force --delete-local-data "$node_id"
else
	"${SLACK}" "Node $node_id does not appear to be in the cluster, skipping node reset and deleting directly from hypervisor..."
fi

hypervisor="$(hope --config hope.yaml node hypervisor "$node_id")"
if ! hope --config hope.yaml vm list "$hypervisor" | grep "^$node_id\$"; then
	"${SLACK}" "Node $node_id seems to not be present on the hypervisor. Exiting early"
	exit
fi

"${SLACK}" "Node rotator removing node $node_id from hypervisor: $hypervisor..."
hope --config hope.yaml vm stop "$node_id"
hope --config hope.yaml vm delete "$node_id"
