#!/bin/bash

if [ $# -ne 4 ]
  then
    echo "usage: $0 <source org> <repo> <target org> [target repo]"
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

source_org=$1
repo=$2
target_org=$3
target_repo=${4:-$repo}

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

function map_role() {
    role=$1
    if [ "$role" = "write" ]; then
        echo "push"
    elif [ "$role" = "read" ]; then
        echo "pull"
    else
        echo "$role"    
    fi
}

function createTeamIfNotExists() {
    source_org=$1
    target_org=$2
    slug=$3

    # https://docs.github.com/en/rest/teams/teams?apiVersion=2022-11-28#get-a-team-by-name
    GH_TOKEN=$TARGET_TOKEN gh api "orgs/$target_org/teams/$slug" --silent
    if [ $? != 0  ]; then
        JSON=$(GH_TOKEN=$SOURCE_TOKEN gh api "orgs/$source_org/teams/$slug" --jq '{name, description, privacy,notification_setting}')

        # https://docs.github.com/en/rest/teams/teams?apiVersion=2022-11-28#create-a-team
        GH_TOKEN=$TARGET_TOKEN gh api --method POST "orgs/$target_org/teams" --input - <<< "$JSON" --silent

        # Remove us from the team, so the team is empty
        ghuser=$(GH_TOKEN=$TARGET_TOKEN gh api user --jq '.login')
        GH_TOKEN=$TARGET_TOKEN gh api --method DELETE  "orgs/$target_org/teams/$slug/memberships/$ghuser" --silent

    fi
}

echo -e "\nGranting Permissions to users:\n"

GH_TOKEN=$SOURCE_TOKEN gh api "repos/$source_org/$repo/collaborators?affiliation=direct" --jq '.[] | [.login,.role_name] | @tsv' | while read -r login role; do
    if [ -n "$MAP_USER_SCRIPT" ]; then
        login=$($MAP_USER_SCRIPT "$login")
    fi

    role=$(map_role "$role")

    echo "Adding user: $login with $role to $target_org/$target_repo"

    ./add-collaborator-to-repository.sh "$target_org" "$target_repo" "$login" "$role"
done

echo -e "\nGranting Permissions to teams:\n"
GH_TOKEN=$SOURCE_TOKEN gh api "repos/$source_org/$repo/teams" --jq '.[] | [.name,.slug,.permission] | @tsv' | while IFS=$'\t' read -r -a fields; do
    name=${fields[0]}
    slug=${fields[1]}
    permission=${fields[2]}
    echo "Adding team: [$name] ($slug) with $permission to $target_org/$target_repo"

    createTeamIfNotExists "$source_org" "$target_org" "$slug"

    GH_TOKEN=$TARGET_TOKEN ./add-team-to-repository.sh "$target_org" "$target_repo" "$slug" "$permission"
done

echo -e "\n"

