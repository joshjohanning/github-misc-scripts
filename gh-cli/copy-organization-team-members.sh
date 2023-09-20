#!/bin/bash

script_path=$(dirname $0)

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

if [ "$source_org" = "$target_org" ]
  then
    echo "source org and target org must be different"
    exit 1
fi

# read all target teams and loops
GH_TOKEN=$TARGET_TOKEN gh api --paginate "orgs/$target_org/teams" --jq '.[].slug' | while read -r slug; do
  # check if team exists at source
  if ! GH_TOKEN=$SOURCE_TOKEN gh api "orgs/$source_org/teams/$slug" --silent ; then 
    echo "Team $slug does not exist at source. Skipping"
  else
    echo "Copying team $slug from $source_org to $target_org"
    "$script_path/copy-team-members.sh" "$source_org" "$slug" "$target_org" "$slug"
  fi
done