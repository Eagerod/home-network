#!/usr/bin/env bash
#
# Simple script that runs rsync against the ShareLaTeX file store and copies it
#   to the backup store.

set -e

rsync -ahuDH --delete --exclude=.sync /var/lib/sharelatex /var/lib/backups