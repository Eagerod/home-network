#!/usr/bin/env bash

if [ $EUID -ne 0 ]; then
    echo >&2 "Not running as root. This script cannot continue."
    exit -1
fi

echo >&2 "Waiting for Docker daemon to start..."

while ! docker ps > /dev/null; do
    echo >&2 "Docker daemon not ready yet. Sleeping for 5 seconds..."
    sleep 5;
done

echo >&2 "Docker daemon started. Bringing up services."

make -C $(dirname $0)
