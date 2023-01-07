#!/usr/bin/env bash
#
# Remove a single node from circulation, and replace it with a freshly imaged
#   node.
#
set -eufo pipefail

LABEL_NAME="aleemhaji.com/oldest"
SLACK_URL="https://slackbot.internal.aleemhaji.com/message"
HOPE_SOURCE_DIR="/src"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

destroy_node() {
    node_id="$1"

    if hope --config hope.yaml node status "$node_id" 2> /dev/null; then
        slack "Node rotator removing node from Kubernetes cluster ($node_id)..."
        hope --config hope.yaml node reset --force --delete-local-data "$node_id"
    else
        slack "Node $node_id does not appear to be healthy on Kubernetes, skipping node reset and deleting directly..."
    fi

    hope_node_template='{{.Name}} {{.Hypervisor}}
    '
    hypervisor="$(hope --config hope.yaml node list --template "$hope_node_template" | awk -v "node=$node_id" '{if ($1 == node) print $2}')"
    if hope --config hope.yaml vm list "$hypervisor" | grep "^$node_id\$"; then
        slack "Node rotator removing node $node_id from hypervisor: $hypervisor..."
        hope --config hope.yaml vm stop "$node_id"
        hope --config hope.yaml vm delete "$node_id"
    fi
}

create_node() {
    node_id="$1"
    slack "Node rotator creating fresh node $node_id"

    hope --config hope.yaml vm create "kubernetes-node" "$node_id"
    hope --config hope.yaml vm start "$node_id"
    hope --config hope.yaml vm ip "$node_id"
    set +x
    echo >&2 "sshpass -p <pass> hope --config hope.yaml node ssh $node_id"
    sshpass -p "$VM_MANAGEMENT_PASSWORD" hope --config hope.yaml node ssh "$node_id"
    set -x
    hope --config hope.yaml node hostname "$node_id" "$node_id"

    slack "Node rotator adding node to cluster $node_id"
    hope --config hope.yaml node init --force "$node_id"
}

cd "$HOPE_SOURCE_DIR"

slack "Node rotator starting on $NODE_NAME..."

# Before even getting into the node creation/deletion flow,
#     make sure all nodes that should be up are up.
# If there's anything unhealthy, pop that one node off the
#     list, and try to bring it up.
if ! node_statuses="$(hope --config hope.yaml node status -t node)"; then
    node_id="$(echo "$node_statuses" | sed '1d' | awk '{if ($2 != "Healthy") print $1}' | head -1)"
    slack "Node rotator found: $node_id as possibly unhealthy. Attempting to restore capacity."
else
    node_id="$(kubectl get nodes -l "$LABEL_NAME=true" -o template="{{range .items}}{{.metadata.name}}{{end}}")"
fi

if [ -z "$node_id" ]; then
	slack "Failed to find oldest node in cluster."
	exit 1
fi

# There's a label selector to prevent this, but just in case
#     that ever changes.
if [ "$node_id" = "$NODE_NAME" ]; then
	slack "Node rotator running on $NODE_NAME wants to kill itself. Failing early."
	exit 1
fi

# kubectl -n dev exec -it -c devbox devbox-0 -- bash
# cd /src && hope --config /src/hope.yaml vm image kubernetes-node
destroy_node "$node_id"
create_node "$node_id"

slack "Node rotator completed with node $node_id"
