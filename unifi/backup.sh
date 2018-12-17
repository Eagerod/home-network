#!/usr/bin/env bash
#
# Simple script that runs UniFi's ACE tool to create a backup, then copies it
#   to the host machine where it can be backed up.
# Note: The UniFi database is already backed up using the MongoDB backup
#   process. This just bundles the database in a significantly more manageable
#   format that can be used to run a system restore.

set -e

docker cp $(docker ps -q --filter name=unifi):/usr/lib/unifi/data/backup/autobackup/. /var/lib/backups/unifi/
