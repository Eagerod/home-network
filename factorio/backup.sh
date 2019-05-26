#!/usr/bin/env bash
#
# Simple script that runs rsync against the saves directory and copies it to
#   the backup store.

set -e

rsync -avhuDH --exclude=.sync /var/lib/factorio/ /var/lib/backups/factorio
