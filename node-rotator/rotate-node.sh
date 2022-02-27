#!/usr/bin/env sh
#
# Remove a single node from circulation, and replace it with a freshly imaged
#   node.
#
LABEL_NAME="aleemhaji.com/oldest"
SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

cd /src
source .env.new
node_id="$(kubectl get nodes -l "$LABEL_NAME=true" -o template="{{range .items}}{{.metadata.name}}{{end}}")"

if [ -z "$node_id" ]; then
	slack "Failed to find oldest node in cluster."
	exit 1
fi

# There's a label selector to prevent this, but just in case
#   that ever changes.
if [ "$node_id" = "$NODE_NAME" ]; then
	slack "Node rotator wants to kill itself. Failing early."
	exit 1
fi

if hope --config hope.yaml kubectl get node $node_id 2> /dev/null; then
	slack "Node rotator running on $NODE_NAME removing node from cluster ($node_id)"
	echo hope --config hope.yaml node reset --force --delete-local-data $node_id
fi

echo hope --config hope.yaml vm stop $node_id
echo hope --config hope.yaml vm delete $node_id
echo hope --config hope.yaml vm create $node_id
echo hope --config hope.yaml vm start $node_id
echo hope --config hope.yaml vm ip $node_id
echo sshpass -p "$VM_MANAGEMENT_PASSWORD" hope --config hope.yaml node ssh $node_id
echo hope --config hope.yaml node hostname $node_id $node_id
echo hope --config hope.yaml node init --force $node_id
