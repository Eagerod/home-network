#!/bin/sh
set -e

if [ -z "${MONGODB_HOST}" ]; then
	echo >&2 "Must provide MONGODB_HOST to backup"
	exit 1
fi

mongo --host ${MONGODB_HOST} --quiet --eval 'db.getMongo().getDBNames().join("\n");' | while read database; do
	set -e

	if [ "$database" = "admin" ] || [ "$database" = "local" ] || [ "$database" = "config" ] || [ "$database" = "unifi_stat" ] || [ "$database" = "dev" ]; then
		echo >&2 "Skipping database $database"
		continue
	fi

	echo >&2 "Backing up database: $database"
	if [ "$database" = "remind-me-bot" ] || [ "$database" = "blobstore" ]; then
		echo >&2 "Skipping logs collection"
		mongodump --host ${MONGODB_HOST} --db "$database" --excludeCollection=logs -o "/var/lib/backups/$database"
	else
		mongodump --host ${MONGODB_HOST} --db "$database" -o "/var/lib/backups/$database"
	fi
done
