#!/usr/bin/env bash
#
# Copy the flows json to the backup dir.

set -e

docker cp $(docker ps -q --filter name=node-red):/root/.node-red/flows_node-red.json /var/lib/backups/node-red/
