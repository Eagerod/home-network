#!/usr/bin/env bash
#
# Remove a single node from circulation, and replace it with a freshly imaged
#   node.
#
set -eufo pipefail

LABEL_NAME="aleemhaji.com/oldest"
SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

destroy_node() {
    node_id="$1"

    if hope --config hope.yaml node status "$node_id" 2> /dev/null; then
        slack "Node rotator removing node from Kubernetes cluster ($node_id)..."
        echo hope --config hope.yaml node reset --force --delete-local-data "$node_id"
    else
        slack "Node $node_id does not appear to be healthy on Kubernetes, skipping node reset and deleting directly..."
    fi

    hope_node_template='{{.Name}} {{.Hypervisor}}
    '
    hypervisor="$(hope --config hope.yaml node list --template "$hope_node_template" | awk -v "node=$node_id" '{if ($1 == node) print $2}')"
    if hope --config hope.yaml vm list "$hypervisor" | grep "^$node_id\$"; then
        slack "Node rotator removing node $node_id from hypervisor: $hypervisor..."
        echo hope --config hope.yaml vm stop "$node_id"
        echo hope --config hope.yaml vm delete "$node_id"
    fi
}

create_node() {
    node_id="$1"
    slack "Node rotator creating fresh node $node_id"

    echo hope --config hope.yaml vm create "$node_id"
    echo hope --config hope.yaml vm start "$node_id"
    echo hope --config hope.yaml vm ip "$node_id"
    echo sshpass -p "$VM_MANAGEMENT_PASSWORD" hope --config hope.yaml node ssh "$node_id"
    echo hope --config hope.yaml node hostname "$node_id" "$node_id"
    echo hope --config hope.yaml node init --force "$node_id"
}

cd /src
source .env.new

# Before even getting into the node creation/deletion flow,
#     make sure all nodes that should be up are up.
# If there's anything unhealthy, pop that one node off the
#     list, and try to bring it up.
if ! node_statuses="$(hope --config hope.yaml node status -t node)"; then
    single_bad_node="$(echo "$node_statuses" | sed '1d' | awk '{if ($2 != "Healthy") print $1}' | head -1)"
    slack "Node rotator found: $single_bad_node as possibly unhealthy. Attempting to restore capacity."
    delete_node "$single_bad_node"
    create_node "$single_bad_node"
    exit
fi

node_id="$(kubectl get nodes -l "$LABEL_NAME=true" -o template="{{range .items}}{{.metadata.name}}{{end}}")"

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

slack "Node rotator starting on $NODE_NAME..."
destroy_node "$node_id"
create_node "$node_id"
