#!/usr/bin/env bash
#
# Label nodes with a value representing whether or not they're the oldest node
#   running in the cluster.
#
set -eufo pipefail

LABEL_NAME="aleemhaji.com/oldest"
NODE_TEMPLATE='{{range .items}}{{.metadata.name}} {{.metadata.creationTimestamp}} {{index .metadata.labels "node-role.kubernetes.io/master"}}
{{end}}'

label_node() {
	if [ $# -ne 2 ]; then
		echo >&2 "usage: label_node <node> <value>"
		return 1
	fi

	node="$1"
	label_value="$2"

	if current_value="$(kubectl label node "$node" --list | grep "^$LABEL_NAME=" | sed "s?$LABEL_NAME=??")"; then
		if [ "$current_value" != "$label_value" ]; then
			kubectl label node "$node" --overwrite "$LABEL_NAME=$label_value"
		else
			echo >&2 "Skipping labeling $node $LABEL_NAME=$label_value becasue it's already set."
		fi
	else
		kubectl label node "$node" "$LABEL_NAME=$label_value"
	fi
}

readarray -t nodes < <(\
	kubectl get nodes -o template="$NODE_TEMPLATE" | \
	awk '{if (NF != 2) print}' | sort -k2 | awk '{print $1}')

node="${nodes[0]}"
label_node "$node" "true"

nodes=("${nodes[@]:1}")
for node in "${nodes[@]}"; do
	label_node "$node" "false"
done
