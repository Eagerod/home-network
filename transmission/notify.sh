#!/usr/bin/env sh
#
# Notify when a torrent finishes downloading.
#
set -euf

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"
SLACK_BOT_ALERTING_CHANNEL="C02Q8J7UKU6"

slack() {
	curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_BOT_ALERTING_CHANNEL}" -d "$@" "$SLACK_URL"
}

slack "${TR_TORRENT_NAME} has finished downloading"
