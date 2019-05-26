#!/usr/bin/env bash

set -e

script_dir=$(dirname $0)
container_backup_dir=/var/lib/backup

rsync -avhuDH --delete --exclude=.sync /var/lib/trilium/ /var/lib/backups/trilium
