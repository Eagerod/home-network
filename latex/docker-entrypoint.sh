#!/usr/bin/env sh
#
set -euf

# shellcheck source=/dev/null
. /app/.venv/bin/activate

exec python3 -u /app/server.py "$@"
