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
ERROR_CODE_NOT_FOUND=3

ignore_tags="latest edge nightly beta preview unstable dev"
global_ignore_tags_selector=""
for rtag in $ignore_tags; do
    global_ignore_tags_selector="$global_ignore_tags_selector | select(test(\"$rtag\") | not)"
done

all_ignore_tags="$(jq -r '. | tostring' "$SCRIPT_DIR/image-monitor-ignore.json")"

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
        repository="$(sed 's_^[^/]*/__' <<< "$registry_repository")"
        registry="$(sed 's_^\([^/]*\).*_\1_' <<< "$registry_repository")"
    else
        registry="hub.docker.com"
        repository="$registry_repository"
    fi

    if [ -z $registry ] || [ -z $repository ] || [ -z $tag ]; then
        echo >&2 "'$1' is not a valid input." 
        echo >&2 "Must include a repository and a tag."
        return $ERROR_CODE_INVALID_INPUT
    fi

    original_repository="$repository"
    if [ "$registry" = "hub.docker.com" ] && ! grep '/' <<< "$repository" > /dev/null; then
        repository="library/$original_repository"
    fi

    t="$(mktemp)"
    # Only the docker hub API offers the tagging date API.
    if [ "$registry" = "hub.docker.com" ]; then
        curl -fsSL "https://$registry/v2/repositories/$repository/tags?page_size=100" > $t
    else
        # Could eventually be expanded to just look at any tags that sort
        #   according to the input.
        # curl -fsSL https://$registry/v2/$repository/tags/list > $t
        echo >&2 "Registry $registry not supported for querying tags"
        return $ERROR_CODE_INVALID_INPUT
    fi

    repository_ignore_tags_selector=""
    for rtag in $(jq -r ".\"$original_repository\"[]" <<< "$all_ignore_tags"); do
        repository_ignore_tags_selector="$repository_ignore_tags_selector | select(test(\"$rtag\") | not)"
    done

    # Check to make sure this tag exists, and get the date it was published.
    push_date=$(jq -r ".results[] | select(.name == \"$tag\").tag_last_pushed" "$t")
    if [ -z $push_date ]; then
        echo >&2 "Failed to find tag $tag in repository for $repository."
        echo >&2 "Returning all tags"
        jq -r ".results[] | select(.images[0].architecture == \"amd64\") | .name $global_ignore_tags_selector $repository_ignore_tags_selector" $t
        rm "$t"
        return
    fi

    jq -r ".results[] | select(.tag_last_pushed > \"$push_date\") | select(.images[0].architecture == \"amd64\") | .name $global_ignore_tags_selector $repository_ignore_tags_selector" "$t"
    rm "$t"
}

function slack() {
    curl -H 'Content-Type: application/json' -d '{
        "Endpoint": "https://slackbot.internal.aleemhaji.com/message",
        "Content": "'"$1"'",
        "Headers": {
            "X-SLACK-CHANNEL-ID": "CKE1AKEAV"
        }
    }' "https://tasks.internal.aleemhaji.com"
}

# Get the list of all images used, and try to find if there are any that are
#   newer than the ones that are currently being used.
# Can also get updatable images with something like:
# $ kubectl get pods -A -o template='{{range .items}}{{range .spec.containers}}{{.image}}
#     {{end}}{{end}}' | grep registry.internal.aleemhaji.com | sort | uniq
curl -fsS "https://raw.githubusercontent.com/Eagerod/home-network/master/hope.yaml" 2> /dev/null | \
    grep 'source:' | \
    sed -r 's/[[:space:]]*source: (.*)/\1/' | \
while read line; do
    set +e
    msg=""
    out="$(check_repository $line)"
    rv=$?
    set -e
    if [ $rv -eq $ERROR_CODE_NOT_FOUND ]; then
        slack "Current tag for $line has been removed."
        continue
    elif [ ! -z "$out" ]; then
        out="$(echo "$out" | tr '[[:space:]]' ' ' | sed 's/ /\\n    /g')"
    else
        # No new tags, nothing to report; up to date!
        continue
    fi

    repository="$(echo "$line" | awk -F: '{print $1}')"
    msg="$(printf "New tags for repository %s:%s%s" "$repository" '\n    ' "$out")"

    if ! echo "$repository" | grep '/' > /dev/null; then
        repository="_/$repository"
    else
        repository="r/$repository"
    fi
    msg="$msg\n Visit https://hub.docker.com/$repository to sift through latest versions."

    slack "$msg"
done
