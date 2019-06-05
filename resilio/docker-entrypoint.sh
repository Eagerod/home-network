#!/bin/bash
#
set -e

if [ -z "${RESILIO_SERVER_USERNAME}" ]; then
    echo >&2 "Username invalid. Set RESILIO_SERVER_USERNAME."
    exit 1
fi

if [ -z "${RESILIO_SERVER_PASSWORD}" ]; then
    echo >&2 "Password invalid. Set RESILIO_SERVER_PASSWORD."
    exit 2
fi

sed "s/webui.username/${RESILIO_SERVER_USERNAME}/g; s/webui.password/${RESILIO_SERVER_PASSWORD}/g" sync.conf > /.sync/sync.conf

exec rslsync --nodaemon --config /.sync/sync.conf
