#!/bin/bash

if [ $# -lt "6" ]; then
    echo "Usage: $0 <org> <template-repo> <repo-to-create> <repo-description> <include-all-branches: true|false> <private: true|false> <visibility: public|internal|private> <optional: hostname>"
    echo "Example: ./create-repository-from-template.sh joshjohanning-org template-repo deleteme12345 test false false internal"
    exit 1
fi

org=$1
template_repo=$2
repo_to_create=$3
repo_description=$4
include_all_branches=${5:-false}
private=${6:-true}
visibility=${7:-"private"}
hostname=${8:-"github.com"}

gh api --hostname $hostname -X POST /repos/$org/$template_repo/generate \
 -f owner="$org" \
 -f name="$repo_to_create" \
 -f description="$repo_description" \
 -F include_all_branches=$include_all_branches \
 -F private=$private # either do true for private or false for public

# if visibility was specified as internal, we need to run 1 more api call to update the visibility
if [ "$visibility" == "internal" ]; then
  result=$(gh api --hostname $hostname -X PATCH /repos/$org/$repo_to_create -f visibility=$visibility | jq -r '"name: \(.name), visibility: \(.visibility)"')
fi
