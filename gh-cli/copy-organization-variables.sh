#!/bin/bash

if [ $# -ne 2 ]
  then
    echo "usage: $0 <source org> <target org>"
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

source_org=$1
target_org=$2

function getRepositoriesIDs() {
    local source_org=$1
    local target_org=$2
    local name=$3

    local _jsonids='[]'

    while read -r repo; do
        # Get target repo id
        __id=$(GH_TOKEN=$TARGET_TOKEN gh api "repos/$target_org/$repo" --jq '.id')

        if [ $? != 0 ]; then
            echo "  ERROR: repository $target_org/$repo not found. Will ignore it" >&2
        else
            _jsonids=$(echo "$_jsonids" | jq -c ". + [${__id}]")
        fi
    done < <(GH_TOKEN=$SOURCE_TOKEN gh api "orgs/$source_org/actions/variables/$name/repositories" --jq '.repositories[].name')

    echo "$_jsonids"
}

function createOrUpdateOrgVariable() {
  local source_org=$1
  local target_org=$2
  local json=$3

  local var_name
  local visibility
  
  var_name=$(jq -r '.name' <<< "$json")
  visibility=$(jq -r '.visibility' <<< "$json")

  if [ "$visibility" = "selected" ]; then
    
    repo_ids=$(getRepositoriesIDs "$source_org" "$target_org" "$var_name")

    json=$(echo "$json" | jq -c ". + {selected_repository_ids: $repo_ids}")    
  fi

  local url
  url="orgs/$target_org/actions/variables"
  if ! GH_TOKEN=$TARGET_TOKEN  gh api "orgs/$target_org/actions/variables/$var_name" > /dev/null 2>&1; then
    echo -e "  creating variable $var_name"
    method=POST
  else
    echo -e "  updating variable $var_name"
    url="$url/$var_name"
    method=PATCH
  fi

  GH_TOKEN=$TARGET_TOKEN gh api --method "$method" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$url" --input - <<< "$json" > /dev/null
}

echo "Copying org variables from $source_org to $target_org"

GH_TOKEN=$SOURCE_TOKEN gh api --paginate "orgs/$source_org/actions/variables" | jq -c '.variables[] | {name,value, visibility}' | while read -r json_item; do
    createOrUpdateOrgVariable "$source_org" "$target_org" "$json_item"
done
