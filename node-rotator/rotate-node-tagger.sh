#!/usr/bin/env bash
#
# Label nodes with a value representing whether or not they're the oldest node
#   running in the cluster.
#
LABEL_NAME="aleemhaji.com/oldest"

node_template='{{range .items}}{{.metadata.name}} {{.metadata.creationTimestamp}} {{index .metadata.labels "node-role.kubernetes.io/master"}}
{{end}}'
nodes=($(kubectl get nodes -o template="$node_template" | awk '{if (NF != 2) print}' | sort -k2 | awk '{print $1}'))

node="${nodes[0]}"
if kubectl label node "$node" --list | grep "^$LABEL_NAME"; then
	kubectl label node $node --overwrite "$LABEL_NAME=true"
else
	kubectl label node $node "$LABEL_NAME=true"
fi

nodes=("${nodes[@]:1}")
for node in ${nodes[@]}; do
	if kubectl label node "$node" --list | grep "^$LABEL_NAME"; then
		kubectl label node $node --overwrite "$LABEL_NAME=false"
	else
		kubectl label node $node "$LABEL_NAME=false"
	fi
done
