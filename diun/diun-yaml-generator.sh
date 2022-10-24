#!/usr/bin/env bash
set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ignore_tags="latest edge nightly beta preview unstable dev"
ignore_tags_list="$(tr ' ' '\n' <<< "$ignore_tags" | sed 's/^/    - /')"

all_ignore_tags="$(jq -r '. | tostring' "$SCRIPT_DIR/image-monitor-ignore.json")"

make_repo_ignore_tags() {
	if [ $# -ne 1 ]; then
		echo >&2 "usage: make_ignore_tags <repo-name>"
		return 1
	fi

    registry_repository_tag="$1"
    registry_repository="$(awk -F: '{print $1}' <<< "$registry_repository_tag")"

    possible_registry="$(awk -F/ '{print $1}' <<< "$registry_repository")"
    if nslookup "$possible_registry" > /dev/null; then
        repository="$(sed 's_^[^/]*/__' <<< "$registry_repository")"
    else
        repository="$registry_repository"
    fi

	repository_ignore_tags_list=""
    for tag in $(jq -r ".\"$repository\"[]" <<< "$all_ignore_tags" 2> /dev/null); do
		echo "    - $tag"
    done
}

cat - | grep "source:" | while read -r line; do
	registry_repo="$(sed -r 's/[[:space:]]*source:[[:space:]]*//' <<< "$line")"
	echo "- name:" "$(awk -F: '{print $1}' <<< "$registry_repo")"
	echo "  notify_on:"
	echo "    - new"
	echo "  exclude_tags:"
	echo "$ignore_tags_list"
	make_repo_ignore_tags "$registry_repo"
done	
