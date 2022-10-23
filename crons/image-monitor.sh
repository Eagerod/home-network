#!/usr/bin/env bash
#
# Find if a new tag has been published to dockerhub after the given tag.
# Only works for new tags, not tag updates.
# For tag updates, use Diun
#
set -eufo pipefail

ignore_tags="latest edge nightly beta preview unstable dev"
global_ignore_tags_selector=""
for rtag in $ignore_tags; do
    global_ignore_tags_selector="$global_ignore_tags_selector | select(test(\"$rtag\") | not)"
done

function check_repository() {
    if [ $# -ne 1 ]; then
        echo >&2 "Usage:"
        echo >&2 "  $0 <tag>"
        return 1
    fi

    repository="$(echo "$1" | awk -F: '{print $1}')"
    tag="$(echo "$1" | awk -F: '{print $2}')"

    if [ -z $repository ] || [ -z $tag ]; then
        echo >&2 "'$1' is not a valid input." 
        echo >&2 "Must include a repository and a tag."
        return 2
    fi

    if ! echo "$repository" | grep '/' > /dev/null; then
        repository="library/$repository"
    fi

    t="$(mktemp)"
    # curl -v -fsSL https://registry.internal.aleemhaji.com/v2/home-network/tags/list
    # curl -v -fsSL https://lscr.io/v2/linuxserver/wireguard/tags/list
    curl -fsSL "https://hub.docker.com/v2/repositories/$repository/tags?page_size=1024" > $t

    # Check to make sure this tag exists, and get the date it was published.
    push_date=$(jq -r ".results[] | select(.name == \"$tag\").tag_last_pushed" "$t")
    if [ -z $push_date ]; then
        echo >&2 "Failed to find tag $tag in repository for $repository."
        return 3
    fi

    jq -r ".results[] | select(.tag_last_pushed > \"$push_date\") | select(.images[0].architecture == \"amd64\") | .name $global_ignore_tags_selector" "$t"
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
curl -fsS "https://raw.githubusercontent.com/Eagerod/home-network/master/hope.yaml" 2> /dev/null | \
    grep 'source:' | \
    sed -r 's/[[:space:]]*source: (.*)/\1/' | \
while read line; do
    set +e
    msg=""
    out="$(check_repository $line)"
    rv=$?
    set -e
    if [ $rv -eq 3 ]; then
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
