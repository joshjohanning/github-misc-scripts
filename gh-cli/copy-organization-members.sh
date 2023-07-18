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

if [ "$source_org" = "$target_org" ]
  then
    echo "source org and target org must be different"
    exit 1
fi

if [ -z "$MAP_USER_SCRIPT" ]; then
    echo "WARNING: MAP_USER_SCRIPT is not set. No mapping will be performed."
    echo "Add a script to the environment variable MAP_USER_SCRIPT to map users from $source_org to $target_org"
  else
    if [ ! -f "$MAP_USER_SCRIPT" ]; then
        echo "MAP_USER_SCRIPT is set to $MAP_USER_SCRIPT"
        echo "ERROR: MAP_USER_SCRIPT is not a file"
        exit 1
    fi
fi

GH_TOKEN=$SOURCE_TOKEN gh api graphql --paginate -F owner="$source_org" -f query='query membersWithRole($owner: String! $endCursor: String) {
  organization(login: $owner) {
    membersWithRole(first: 100, after: $endCursor) {
      pageInfo {
        hasNextPage
        endCursor
      }
      edges {
        role
        node {
          login
        }
      }
    }
  }
}' --jq '.data.organization.membersWithRole.edges[] | [.node.login, .role] | @tsv'  | while read -r login role; do

  if [ -n "$MAP_USER_SCRIPT" ]; then
    login=$($MAP_USER_SCRIPT "$login")
  fi

  login=$($MAP_USER_SCRIPT "$login")
  role=$(echo "$role" | tr '[:upper:]' '[:lower:]')
  echo "Adding $login with role $role to $target_org"

  GH_TOKEN=$TARGET_TOKEN gh api \
    --method PUT -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
    "orgs/$target_org/memberships/$login" -f role="$role" --silent 

done