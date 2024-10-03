#!/bin/bash

# changes the visibility of a repository

if [ $# -lt "3" ]; then
    echo "Usage: $0 <org> <repo> <visibility: public|internal|private> <optional: hostname>"
    exit 1
fi

org=$1
repo=$2
visibility=$3
hostname=${4:-"github.com"}

# alternative with gh api (can be used to modify multiple properties of repo at once):
result=$(gh api --hostname $hostname -X PATCH /repos/$org/$repo -f visibility=$visibility | jq -r '"name: \(.name), visibility: \(.visibility)"')

if [ $? -eq 0 ]; then
  echo "$result"
fi

# using gh repo edit native cli:
# gh repo edit $org/$repo --visibility $visibility
