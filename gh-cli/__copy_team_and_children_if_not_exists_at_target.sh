#!/bin/bash

# NOTE: this script is called from copy-permissions-between-org-repos.sh it's not meant to be called directly

if [ $# -lt 3 ]; then
    echo "usage: $0 <source org> <target org> <slug> <parent slug> <parent id> [logfilename]"
    echo "WARNING: this is an internal function. Do not call directly"
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
target_org=$2
slug=$3
parent_slug=$4
parent_id=$5

script_path=$(dirname "$0")

RED='\033[0;31m'
function debug() {
    if [ "$DEBUG" = "true" ]; then
        echo -e "${RED}DBG: $@" >&2
        # reset color
        echo -e "\033[0m" >&2
    fi
}

debug "__copy_team_if_not_exists_at_target.sh $source_org $target_org $slug parent=$parent_slug $parent_id"

# Get team details from source
SOURCE_TEAM_JSON=$(GH_TOKEN=$SOURCE_TOKEN gh api "orgs/$source_org/teams/$slug" --jq '{name, description, privacy, notification_setting, parent_id:. .parent.id  ,parent_slug: .parent.slug}')

# https://docs.github.com/en/rest/teams/teams?apiVersion=2022-11-28#get-a-team-by-name
if ! TARGET_TEAM_JSON=$(GH_TOKEN=$TARGET_TOKEN gh api "orgs/$target_org/teams/$slug" --jq '{name, description, privacy,notification_setting, id: .id, parent_id:. .parent.id, parent_slug: .parent.slug}' 2>/dev/null); then
    echo "  $slug does not exist at target. Creating it"

    SOURCE_TEAM_JSON=$(echo "$SOURCE_TEAM_JSON" | jq 'del(.id) | del(.parent_id) | del(.parent_slug)')

    if [ -n "$parent_id" ]; then
        SOURCE_TEAM_JSON=$(echo "$SOURCE_TEAM_JSON" | jq --argjson parent_id "$parent_id" '.parent_team_id = $parent_id')
    fi

    parent_desc=""
    if [ -n "$parent_slug" ]; then
        parent_desc=" with parent $parent_slug ($parent_id)"
    fi

    debug "CREATING $slug with $SOURCE_TEAM_JSON"

    # https://docs.github.com/en/rest/teams/teams?apiVersion=2022-11-28#create-a-team
    new_team_id=$(GH_TOKEN=$TARGET_TOKEN gh api --method POST "orgs/$target_org/teams" --input - --jq .id <<<"$SOURCE_TEAM_JSON")

    echo "  Created team $slug ($new_team_id) $parent_desc"

    # Remove us from the team, so the team is empty
    if [ -z "$__ghuser" ]; then
        __ghuser=$(GH_TOKEN=$TARGET_TOKEN gh api user --jq '.login')
    fi
    GH_TOKEN=$TARGET_TOKEN gh api --method DELETE "orgs/$target_org/teams/$slug/memberships/$__ghuser" --silent
else

    target_parent_id=$(echo "$TARGET_TEAM_JSON" | jq -r '.parent_id')
    target_parent_slug=$(echo "$TARGET_TEAM_JSON" | jq -r '.parent_slug')

    debug "Found existing team $slug at target with $TARGET_TEAM_JSON"

    parent_desc=""
    if [ "$target_parent_slug" != "null" ]; then
        parent_desc="with parent [$target_parent_slug]"
    fi
    echo "  Team $slug already exists at target $parent_desc"

    # Set parentid?
    if [ -n "$parent_id" ]; then
    
        if [ "$target_parent_id" != "$parent_id" ]; then
            if [ "$target_parent_id" != "null" ]; then
                echo "  WARNING: Team [$slug] already has a parent [$target_parent_slug] with id [$target_parent_id]. State is ambiguous. Skipping it (If this is not intentional you will need to fix it manually)."
            else
                echo "  Set parent [$parent_slug] to [$slug]"
                GH_TOKEN=$TARGET_TOKEN gh api -X PATCH "orgs/$target_org/teams/$slug" \
                    -F parent_team_id="$parent_id" \
                    -f privacy=closed \
                    --silent
            fi

        fi
    fi

    new_team_id=$(echo "$TARGET_TEAM_JSON" | jq -r '.id')

    debug "Using existing team $slug with id $new_team_id"
fi

# Get child teams and create them/parent them
GH_TOKEN=$SOURCE_TOKEN gh api "orgs/$source_org/teams/$slug/teams" --jq '.[].slug' | while read -r child_slug; do
    # Recursive call to create the child team
    "$0" "$source_org" "$target_org" "$child_slug" "$slug" "$new_team_id"
done
