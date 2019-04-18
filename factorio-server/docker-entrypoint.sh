#!/bin/bash

set -e

: ${SERVER_TOKEN=''}
: ${GAME_PUBLIC=false}
: ${AUTH_REQUIRED=false}

sed -i -r 's/("require_user_verification"\s*:\s*).*/\1'$AUTH_REQUIRED',/g' "$DATA_DIR/server-settings.json"
sed -i -r 's/("token"\s*:\s*).*/\1"'$SERVER_TOKEN'",/g' "$DATA_DIR/server-settings.json"
sed -i -r 's/("public"\s*:\s*).*/\1'$GAME_PUBLIC',/g' "$DATA_DIR/server-settings.json"

if [ ! -f "$SAVE_DIR/$SAVE_GAME.zip" ]; then 
    factorio --create "$SAVE_DIR/$SAVE_GAME.zip"
fi

exec factorio --server-settings "$DATA_DIR/server-settings.json" --start-server "$SAVE_DIR/$SAVE_GAME.zip"
