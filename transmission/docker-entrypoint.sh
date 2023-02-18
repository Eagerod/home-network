#!/bin/sh
set -euf

if [ -z "$PEER_PORT" ]; then
    echo >&2 "Must define \$PEER_PORT."
    exit 1
fi

CONFIG_DIR=/var/lib/transmission-daemon/info
WATCH_DIR=/var/lib/transmission-daemon/watch
INCOMPLETE_DIR=/var/lib/incomplete-downloads

mkdir -p "$CONFIG_DIR" "$WATCH_DIR"

sed 's/"peer-port".*/"peer-port": '"$PEER_PORT"',/' /tmp/settings.json > "$CONFIG_DIR/settings.json"

if [ -d "$INCOMPLETE_DIR" ]; then
    echo "Starting transmission with incomplete dir."
    exec transmission-daemon -f --config-dir "$CONFIG_DIR" --watch-dir "$WATCH_DIR" --incomplete-dir "$INCOMPLETE_DIR"
else
    exec transmission-daemon -f --config-dir "$CONFIG_DIR" --watch-dir "$WATCH_DIR"
fi
