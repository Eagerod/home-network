#!/usr/bin/env bash
#
# Simple script that runs mysqldump sequentially over all MySQL databases and
#   tables, writing them to a backup directory.

set -e

script_dir=$(dirname $0)
container_backup_dir=/var/lib/backup

source "$script_dir/.env"

docker exec -u root -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" -e BACKUP_DIR="$container_backup_dir" -it $(docker ps -q --filter name=mysql) bash -c '\
    mysql -u root -s -N -e "show databases;" | while read database; do \
        mkdir -p "$BACKUP_DIR/$database"; \
        mysql -u root -s -N -c "$database" -e "show tables;" | while read table; do \
            mysqldump -u root --skip-dump-date "$database" "$table" > "$BACKUP_DIR/$database/$table.sql"; \
        done; \
    done'
