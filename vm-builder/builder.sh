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

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOPE_SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

cd "$HOPE_SOURCE_DIR"

slack "VM builder running on $NODE_NAME..."

if [ $# -eq 1 ]; then
    vm_name="$1"
    slack "VM builder will build $vm_name"
else
    slack "VM builder not given a vm name to build. Exiting early"
	exit 1
fi

hope --config hope.yaml vm image "$vm_name"

slack "Node rotator completed with vm $vm_name"
