#!/usr/bin/env sh
#
# Send a message via. slackbot to the channel specified by 
# $SLACK_BOT_ALERTING_CHANNEL, if provided
set -euf

if [ $# -lt 1 ]; then
	echo >&2 "usage: $0 <message>"
	exit 1
fi

SLACK_BOT_ALERTING_CHANNEL=${SLACK_BOT_ALERTING_CHANNEL:-}
SLACK_URL="https://slackbot.internal.aleemhaji.com/message"

echo >&2 "Slack: $*"
if ! curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"; then
	echo >&2 "Failed to send message to Slack: $*"
fi
