#!/usr/bin/env sh
#
# Upload a files to bookstack in a new page under the given book.
#
set -eufx

BOOKSTACK_DOMAIN="https://bookstack.internal.aleemhaji.com"
BOOKSTACK_API_PREFIX="$BOOKSTACK_DOMAIN/api"

CURL_AUTH_HEADER="Authorization: Token $TOKEN_ID:$TOKEN_SECRET"

if [ $# -ne 0 ]; then
	echo >&2 "Usage:"
	echo >&2 "  $0"
	exit 1
fi

today="$(date -u +%Y-%m-%d)"

curl -H "$CURL_AUTH_HEADER" -fsSL "$BOOKSTACK_API_PREFIX/search?query=\[notify\]" |\
	jq -r --arg "date=$today" -r '.data[] | .tags[] + {item_name: .name, url} | select(.name = "notify") | "\(.value) [\(.item_name)](\(.url))"' |\
	awk -v "date=$today" '{if ($1 <= date) print}'
