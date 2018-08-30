#!/usr/bin/env bash

if [ $EUID -ne 0 ]; then
    echo >&2 "Not running as root. This script cannot continue."
    exit -1
fi

while ! docker ps; do
    sleep 5;
done

make -C $(dirname $0)
