#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <repo>"
  echo "repo in the format owner/repo"
  exit 1
fi

repo=$1

# validate if repo is in format owner/repo
if [[ ! $repo =~ ^[[:alnum:]_-]+/[[:alnum:]_-]+$ ]]; then
  echo "ERROR: invalid repo format. Expected owner/repo"
  exit 1
fi

# iterate on all repo webhooks and delete them
gh api -H "X-GitHub-Api-Version: 2022-11-28" "/repos/$repo/hooks" --jq '.[].id' | while read -r id; do
  echo "deleting webhook $id"
  gh api -X DELETE "repos/$repo/hooks/$id"
done 

