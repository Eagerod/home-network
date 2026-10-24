#!/bin/sh
set -e

if [ -z "${PGHOST}" ]; then
    echo >&2 "Must provide PGHOST to backup"
    exit 1
fi

if [ -z "${PGPASSWORD}" ]; then
    echo >&2 "Must provide PGPASSWORD for postgres@${PGHOST}"
    exit 2
fi

psql -h "${PGHOST}" -U postgres -d postgres -Atc \
    "SELECT datname FROM pg_database WHERE datistemplate = false;" |
while IFS= read -r database; do
    if [ "$database" = "postgres" ]; then
        echo >&2 "Skipping database $database"
        continue
    fi

    echo >&2 "Backing up database: $database"
    mkdir -p "/var/lib/backups/$database"

    psql -h "${PGHOST}" -U postgres -d "$database" -Atc \
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public';" |
    while IFS= read -r table; do
        pg_dump \
            -h "${PGHOST}" \
            -U postgres \
            --no-owner \
            --no-privileges \
            --table="public.${table}" \
            "$database" \
            > "/var/lib/backups/$database/$table.sql"
    done || exit 1
done || exit 1
