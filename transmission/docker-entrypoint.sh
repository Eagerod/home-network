#!/bin/sh

CONFIG_DIR=/var/lib/transmission-daemon/info
WATCH_DIR=/var/lib/transmission-daemon/watch

mkdir -p "$CONFIG_DIR" "$WATCH_DIR"

mv /tmp/settings.json "$CONFIG_DIR/settings.json"

exec transmission-daemon -f --config-dir "$CONFIG_DIR" --watch-dir "$WATCH_DIR"
