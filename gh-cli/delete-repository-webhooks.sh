#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 <owner> <repo>"
  exit 1
fi

owner=$1
repo=$2

# iterate on all repo webhooks and delete them
gh api -H "X-GitHub-Api-Version: 2022-11-28" "/repos/$owner/$repo/hooks" --jq '.[].id' | while read -r id; do
  echo "deleting webhook $id"
  gh api -X DELETE "repos/$repo/hooks/$id"
done 

