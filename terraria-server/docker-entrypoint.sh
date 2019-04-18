#!/bin/bash

set -e

: ${NEW_WORLD_SIZE=2}

BIN='mono /var/lib/tshock/TerrariaServer.exe'

SAVES_PATH=/var/lib/terraria
WORLD_PATH=$SAVES_PATH/$WORLD.wld

if [ ! -f $WORLD_PATH ]; then
    exec $BIN -autocreate $NEW_WORLD_SIZE -world $WORLD_PATH -worldpath $SAVES_PATH
else
    exec $BIN -world "${WORLD_PATH}"
fi
