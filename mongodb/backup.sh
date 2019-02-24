#!/usr/bin/env bash
#
# Simple script that runs mongodump sequentially on the MongoDB instance and
#   writes all databases and collections to the backup directory

set -e

script_dir=$(dirname $0)
container_backup_dir=/var/lib/backup

docker exec -u root $(docker ps -q --filter name=mongodb) mongodump -o $container_backup_dir
