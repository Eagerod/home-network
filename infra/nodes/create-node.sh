#!/usr/bin/env sh
#
# Ensure the given node is available within the cluster.
# If it already exists, exits early.
#
set -xeufo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLACK="${SCRIPT_DIR}/slack.sh"

if [ $# -ne 2 ]; then
	echo >&2 "usage: $0 <image-name> <node-name>"
	exit 1
fi

vm_image_name="$1"
node_id="$2"

if [ -z "$VM_MANAGEMENT_PASSWORD" ]; then
	echo >&2 "Will not be able to configure SSH on $node_id without \$VM_MANAGEMENT_PASSWORD"
	exit 2
fi

if hope --config hope.yaml kubectl get node "$node_id" 2> /dev/null; then
	echo "$node_id already in cluster. Exiting early"
	exit 0
fi

hypervisor="$(hope --config hope.yaml node hypervisor "$node_id")"
if ! hope --config hope.yaml vm list "$hypervisor" | grep "^${node_id}\$"; then
	"${SLACK}" "Node manager creating fresh node $node_id"
	hope --config hope.yaml vm create "$vm_image_name" "$node_id"
fi

hope --config hope.yaml vm start "$node_id"
hope --config hope.yaml vm ip "$node_id"

set +x
echo >&2 "sshpass -p <pass> hope --config hope.yaml node ssh $node_id"
sshpass -p "$VM_MANAGEMENT_PASSWORD" hope --config hope.yaml node ssh "$node_id"
set -x

hope --config hope.yaml node hostname "$node_id" "$node_id"

"${SLACK}" "Node manager adding node to cluster $node_id"
hope --config hope.yaml node init --force "$node_id"
