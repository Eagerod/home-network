#!/bin/sh

if [ -z $PEER_PORT ]; then
    echo >&2 "Must define \$PEER_PORT."
    exit 1
fi

CONFIG_DIR=/var/lib/transmission-daemon/info
WATCH_DIR=/var/lib/transmission-daemon/watch

mkdir -p "$CONFIG_DIR" "$WATCH_DIR"

sed 's/"peer-port".*/"peer-port": '$PEER_PORT',/' /tmp/settings.json > "$CONFIG_DIR/settings.json"

exec transmission-daemon -f --config-dir "$CONFIG_DIR" --watch-dir "$WATCH_DIR"
