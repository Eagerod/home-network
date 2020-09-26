#!/bin/bash
set -e

if [ -z $SAVE_GAME ]; then
	echo >&2 "No save game name provided. Please provide \$SAVE_GAME to continue."
	exit 1
fi

SERVER_SETTINGS_FILE=/var/lib/factorio/data/server-settings.json
SERVER_SAVE_GAME=/var/lib/factorio/saves/$SAVE_GAME.zip

: ${SERVER_TOKEN=''}
: ${GAME_PUBLIC=false}
: ${AUTH_REQUIRED=false}

sed -i -r 's/("require_user_verification"\s*:\s*).*/\1'$AUTH_REQUIRED',/g' "$SERVER_SETTINGS_FILE"
sed -i -r 's/("token"\s*:\s*).*/\1"'$SERVER_TOKEN'",/g' "$SERVER_SETTINGS_FILE"
sed -i -r 's/("public"\s*:\s*).*/\1'$GAME_PUBLIC',/g' "$SERVER_SETTINGS_FILE"

if [ ! -f "$SERVER_SAVE_GAME" ]; then 
    factorio --create "$SERVER_SAVE_GAME"
fi

exec factorio --server-settings "$SERVER_SETTINGS_FILE" --start-server "$SERVER_SAVE_GAME"
