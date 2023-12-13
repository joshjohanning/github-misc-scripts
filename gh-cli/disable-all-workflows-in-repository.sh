#!/bin/bash

# This disables all workflows in a repository
#   - helpful if forking or copying someone else's code and you don't want all of the actions to continuously trigger

set -e

if [ $# -ne "2" ]; then
    echo "Usage: $0 <org> <repo>"
    exit 1
fi

org=$1
repo=$2

workflows=$(gh workflow list -R "$org/$repo" --json 'id' -q '.[].id')
# each $workflows
for workflow in $workflows
do
  echo "disabling workflow: $workflow"
  gh workflow disable -R "$org/$repo" "$workflow"
done
