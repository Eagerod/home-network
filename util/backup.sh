#!/usr/bin/env bash
#
# Script that will traverse through git repositories, and run `gc` against them
#   before copying the contents out to a backup directory.

set -e

script_dir=$(dirname $0)
git_repositories_dir=/var/lib/git
git_backup_dir=/var/lib/backups/git

echo >&2 "Starting traversal through repositories directory."

find "$git_repositories_dir" -type d -mindepth 1 -maxdepth 1 -print | while read repo; do
    if ! git -C ${repo} rev-parse --git-dir > /dev/null 2> /dev/null; then
        echo >&2 "(${repo}) exists in repositories directory, and is not a repo."
        continue
    fi
    git -C "${repo}" for-each-ref | awk '{print $1}' | while read ref; do
        if [ ! -z "$(git -C ${repo} log --since='1 hour' ${ref})" ]; then
            git -C ${repo} gc
            echo >&2 "(${repo}) had changes and warranted garbage collection."
            break
        else 
            echo >&2 "(${repo}) unchanged."
        fi
    done
done

echo >&2 "Completed traversal."

rsync -avhuDH --delete --exclude=.sync "${git_repositories_dir}/" "${git_backup_dir}"
