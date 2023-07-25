#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 <source org> <source team> <target org> [target team]"
    exit 1
fi

if [ -z "$SOURCE_TOKEN" ]; then
    echo "SOURCE_TOKEN must be set"
    exit 1
fi

if [ -z "$TARGET_TOKEN" ]; then
    echo "TARGET_TOKEN must be set"
    exit 1
fi

source_org=$1
source_team=$2
target_org=$3
target_team=${4:-$source_team}

# Check if target team exists
if ! GH_TOKEN=$TARGET_TOKEN gh api --silent "/orgs/$target_org/teams/$target_team" > /dev/null 2>&1; then
    echo "Error: Target team $target_org/$target_team does not exist"
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

echo -e "\ncopying members from $source_org/$source_team to $target_org/$target_team\n"

GH_TOKEN=$SOURCE_TOKEN gh api graphql -f org="$source_org" -f teamslug="$source_team" -F query='query($org:String! $teamslug:String! $cursor:String) {
  organization(login: $org) {
    team(slug: $teamslug) {
      members(first: 100, after:$cursor, membership: IMMEDIATE) {
        pageInfo {
          hasNextPage
          endCursor
        }
        edges {
          node {
            login
          }
          role
        }
      }
    }
  }
}' --jq '.data.organization.team.members.edges[] | [.node.login, .role] | @tsv' | while read -r login role; do

    if [ -n "$MAP_USER_SCRIPT" ]; then
        login=$($MAP_USER_SCRIPT "$login")
    fi

    role=$(echo "$role" | tr '[:upper:]' '[:lower:]')
    echo "  Adding $login with role $role to $target_org/$target_team"
    if ! GH_TOKEN=$TARGET_TOKEN gh api --silent --method PUT "/orgs/$target_org/teams/$target_team/memberships/$login" -f role="$role" ; then
        echo "  Error adding $login to $target_org/$target_team"
    fi
done

