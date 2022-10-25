#!/usr/bin/env bash
#
# Find if a new tag has been published to dockerhub after the given tag.
# Only works for new tags, not tag updates.
# For tag updates, use Diun
#
set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ERROR_CODE_INVALID_USAGE=1
ERROR_CODE_INVALID_INPUT=2

SLACK_URL="https://slackbot.internal.aleemhaji.com/message"
SLACK_CHANNEL="CKE1AKEAV"

ignore_tags="latest edge nightly beta preview unstable dev stable testing"
global_ignore_tags_selector=""
for rtag in $ignore_tags; do
    global_ignore_tags_selector="$global_ignore_tags_selector | select(test(\"^$rtag$\") | not)"
done

all_ignore_tags="$(jq -r '. | tostring' "$SCRIPT_DIR/image-monitor-ignore.json")"

slack() {
    curl -sS -X POST -H "X-SLACK-CHANNEL-ID: ${SLACK_CHANNEL}" -d "$@" "$SLACK_URL"
}

staging_file="$(mktemp)"
trap 'rm -f $staging_file' EXIT

function check_repository() {
    if [ $# -ne 1 ]; then
        echo >&2 "Usage:"
        echo >&2 "  $0 <tag>"
        return $ERROR_CODE_INVALID_USAGE
    fi

    registry_repository_tag="$1"
    registry_repository="$(awk -F: '{print $1}' <<< "$registry_repository_tag")"
    tag="$(awk -F: '{print $2}' <<< "$registry_repository_tag")"

    possible_registry="$(awk -F/ '{print $1}' <<< "$registry_repository")"
    if nslookup "$possible_registry" > /dev/null; then
        repository="${registry_repository#*/}"
        registry="$possible_registry"
    else
        registry="hub.docker.com"
        repository="$registry_repository"
    fi

    if [ -z "$registry" ] || [ -z "$repository" ] || [ -z "$tag" ]; then
        echo >&2 "'$1' is not a valid input." 
        echo >&2 "Must include a repository and a tag."
        return $ERROR_CODE_INVALID_INPUT
    fi

    original_repository="$repository"
    if [ "$registry" = "hub.docker.com" ] && ! grep '/' <<< "$repository" > /dev/null; then
        repository="library/$original_repository"
    fi

    # Only the docker hub API offers the tagging date API.
    if [ "$registry" = "hub.docker.com" ]; then
        curl -fsSL "https://$registry/v2/repositories/$repository/tags?page_size=100" > "$staging_file"
    else
        # Could eventually be expanded to just look at any tags that sort
        #   according to the input.
        # curl -fsSL https://$registry/v2/$repository/tags/list > "$staging_file"
        echo >&2 "Registry $registry not supported for querying tags"
        return $ERROR_CODE_INVALID_INPUT
    fi

    repository_ignore_tags_selector=""
    for rtag in $(jq -r ".\"$original_repository\"[]" <<< "$all_ignore_tags"); do
        repository_ignore_tags_selector="$repository_ignore_tags_selector | select(test(\"$rtag\") | not)"
    done

    # Check to make sure this tag exists, and get the date it was published.
    result_filter="select(.images[0].architecture == \"amd64\") | .name $global_ignore_tags_selector $repository_ignore_tags_selector"
    push_date=$(jq -r ".results[] | select(.name == \"$tag\").tag_last_pushed" "$staging_file")
    if [ -z "$push_date" ]; then
        echo >&2 "Failed to find tag $tag in repository for $repository."
        echo >&2 "Returning all tags"
    else
        result_filter="select(.tag_last_pushed > \"$push_date\") | $result_filter"
    fi

    jq -r ".results[] | $result_filter" "$staging_file"
}

# Get the list of all images used, and try to find if there are any that are
#   newer than the ones that are currently being used.
# Can also get updatable images with something like:
# $ kubectl get pods -A -o template='{{range .items}}{{range .spec.containers}}{{.image}}
#     {{end}}{{end}}' | grep registry.internal.aleemhaji.com | sort | uniq
curl -fsS "https://raw.githubusercontent.com/Eagerod/home-network/master/hope.yaml" 2> /dev/null | \
    grep 'source:' | \
    sed -r 's/[[:space:]]*source:[[:space:]]*(.*)/\1/' | \
while read -r line; do
    out="$(check_repository "$line" || true)"
    if [ -n "$out" ]; then
        out="$(tr '[:space:]' ' ' <<< "$out" | sed 's/ /\\n    /g')"
    else
        # No new tags, nothing to report; up to date!
        continue
    fi

    repository="$(awk -F: '{print $1}' <<< "$line")"
    msg="$(printf "New tags for repository %s:%s%s" "$repository" '\n    ' "$out")"

    if ! grep '/' <<< "$repository" > /dev/null; then
        repository="_/$repository"
    else
        repository="r/$repository"
    fi

    # shellcheck disable=SC1117
    msg="$msg\n Visit https://hub.docker.com/$repository to sift through latest versions."

    slack "$msg"
done
