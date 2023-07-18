#!/bin/bash

if [ $# -ne 4 ]
  then
    echo "usage: $0 <source org> <source repo> <target org> [target repo]"
    echo "If target repo is skipped the name will be same as the source repo"
    exit 1
fi

if [ -z "$SOURCE_TOKEN" ]
  then
    echo "SOURCE_TOKEN must be set"
    exit 1
fi

if [ -z "$TARGET_TOKEN" ]
  then
    echo "TARGET_TOKEN must be set"
    exit 1
fi

source_owner=$1
source_repo=$2
target_owner=$3
target_repo=${4:-$repo}

function createOrUpdateRepoVariable() {
  local name=$1
  local value=$2
  local repo=$3

  if ! gh api "repos/$repo/actions/variables/$name" > /dev/null 2>&1; then
    echo -e "  creating variable $name"
    gh api --method POST -H "X-GitHub-Api-Version: 2022-11-28" \
        "repos/$repo/actions/variables" \
        -f name="$name" -f value="$value" > /dev/null
  else
    echo -e "  updating variable $name"
      gh api --method PATCH -H "X-GitHub-Api-Version: 2022-11-28" \
        "repos/$repo/actions/variables/$name" \
        -f name="$name" -f value="$value" > /dev/null
  fi
}

echo "Copying repo variables from $source_owner/$source_repo to $target_owner/$target_repo"

GH_TOKEN=$SOURCE_TOKEN gh api "repos/$source_owner/$source_repo/actions/variables" | jq -c '.variables[] | {name,value}' | while read -r json_item; do

    name=$(echo "$json_item" | jq -r '.name')
    value=$(echo "$json_item" | jq -r '.value')

    GH_TOKEN=$TARGET_TOKEN createOrUpdateRepoVariable "$name" "$value" "$target_owner/$target_repo"
done
