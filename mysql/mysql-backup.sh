#!/bin/sh
set -e

if [ -z "${MYSQL_HOST}" ]; then
    echo >&2 "Must provide MYSQL_HOST to backup"
    exit 1
fi

if [ -z "${MYSQL_PWD}" ]; then
    echo >&2 "Must provide MYSQL_PWD for root@${MYSQL_HOST}"
    exit 2
fi

mysql -h "${MYSQL_HOST}" -u root -s -N -e "show databases;" | while read database; do
    if [ "$database" = "information_schema" ] || [ "$database" = "mysql" ] || [ "$database" = "sys" ] || [ "$database" = "performance_schema" ]; then
        echo >&2 "Skipping database $database"
        continue
    fi

    echo >&2 "Backing up database: $database"
    mkdir -p "/var/lib/backups/$database"
    mysql -h "${MYSQL_HOST}" -u root -s -N -c "$database" -e "show tables;" | while read table; do
        mysqldump -h "${MYSQL_HOST}" -u root --skip-dump-date "$database" "$table" > "/var/lib/backups/$database/$table.sql"
    done || exit 1
done || exit 1
