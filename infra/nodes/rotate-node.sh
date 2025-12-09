#!/usr/bin/env bash
#
# Remove a single node from circulation, and replace it with a freshly imaged
#   node.
# When run with no arguments, will destroy + recreate the oldest
#   non-control-plane node in the cluster.
# When run with a single argument, will destroy + recreate the named node,
#   even if that node is a control-plane node.
#
set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLACK="${SCRIPT_DIR}/slack.sh"
CREATE_NODE_SCRIPT="${SCRIPT_DIR}/create-node.sh"
DELETE_NODE_SCRIPT="${SCRIPT_DIR}/delete-node.sh"

LABEL_NAME="aleemhaji.com/oldest"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
HOPE_SOURCE_DIR="$(dirname "$INFRA_DIR")"

VM_IMAGE_NAME="${VM_IMAGE_NAME:-kubernetes-node}"

destroy_node() {
    "${DELETE_NODE_SCRIPT}" "$1"
}

create_node() {
    "${CREATE_NODE_SCRIPT}" "$VM_IMAGE_NAME" "$1"
}

get_unhealthy_node() {
    if ! node_statuses="$(hope --config hope.yaml node status -t node)"; then
        sed '1d' <<< "$node_statuses" | awk '{if ($2 != "Healthy") print $1}' | head -1
    fi
}

get_oldest_node() {
    kubectl get nodes -l "$LABEL_NAME=true" -o template="{{range .items}}{{.metadata.name}}{{end}}"
}

cd "$HOPE_SOURCE_DIR"

"${SLACK}" "Node rotator starting on $NODE_NAME..."

if [ $# -eq 1 ]; then
    node_id="$1"
    "${SLACK}" "Node rotator given argument to rotate node: $node_id"
elif [ $# -ne 0 ]; then
    "${SLACK}" "Node rotator given invalid arguments. ($*) Aborting."
    exit 1
else
    node_id="$(get_unhealthy_node)"
    if [ -n "$node_id" ]; then
        "${SLACK}" "Node rotator found: $node_id as possibly unhealthy. Attempting to restore capacity."
    else
        node_id="$(get_oldest_node)"
    fi
fi

if [ -z "$node_id" ]; then
	"${SLACK}" "Failed to find a node to rotate."
	exit 1
fi

# There's a label selector to prevent this, but just in case
#     that ever changes.
if [ "$node_id" = "$NODE_NAME" ]; then
	"${SLACK}" "Node rotator running on $NODE_NAME wants to kill itself. Failing early."
	exit 1
fi

# kubectl -n dev exec -it -c devbox devbox-0 -- bash
# cd /src && hope --config /src/hope.yaml vm image kubernetes-node
destroy_node "$node_id"
create_node "$node_id"

"${SLACK}" "Node rotator completed with node $node_id"
