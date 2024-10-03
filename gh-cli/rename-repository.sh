#!/bin/bash

# renames a repository

if [ -z "$3" ]; then
  echo "Usage: $0 <org> <repo> <new-repo-name> <optional: hostname>"
  exit 1
fi

org="$1"
repo="$2"
new_repo_name="$3"
hostname=${4:-"github.com"}

# alternative with gh api (can be used to modify multiple properties of repo at once):
gh api -X PATCH /repos/$org/$repo -f name="$new_repo_name"

# using gh repo edit native cli:
# gh repo rename --repo $org/$repo $new_repo_name
