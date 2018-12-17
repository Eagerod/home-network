#!/usr/bin/env bash
#
# Simple script that runs UniFi's ACE tool to create a backup, then copies it
#   to the host machine where it can be backed up.

set -e

docker cp $(docker ps -q --filter name=unifi):/usr/lib/unifi/data/backup/autobackup/. /var/lib/backups/unifi/
