#!/usr/bin/env bash
#
# This script runs a few validation steps to make sure that pushes to any
#   remote do not contain information that is obviously sensitive.
# This shouldn't be treated as the only way of prevent unexpected leaks, but it
#   can provide a little extra protection as a last line of defense.
#
set -e

# Note: This script runs from the project root, so no need to do extra path
#   manipulation.
make search-env
