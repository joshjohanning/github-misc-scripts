#!/bin/bash

# NOTE: this script is called from parent-organization-teams.sh it's not meant to be called directly

if [ $# -lt 3 ]; then
    echo "usage: $0 <source org> <target org> <slug> [logfilename]"
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
LOGFILE=$4

RED='\033[0;31m'
function debug() {
    if [ "$DEBUG" = "true" ]; then
        echo -e "${RED}DBG: $@" >&2
        # reset color
        echo -e "\033[0m" >&2
    fi
}
function log() {
    if [ -n "$LOGFILE" ]; then
        echo "  $@" >> "$LOGFILE"
    fi
}

debug "internal/__copy_team_and_parents_if_not_exists_at_target.sh $source_org $target_org [$slug]"

# Get team details from source
JSON=$(GH_TOKEN=$SOURCE_TOKEN gh api "orgs/$source_org/teams/$slug" --jq '{name, description, privacy, notification_setting, parent_id:. .parent.id  ,parent_slug: .parent.slug}')

debug "JSON SOURCE $slug : $JSON"

source_parent_id=$(echo "$JSON" | jq -r '.parent_id')
source_parent_slug=$(echo "$JSON" | jq -r '.parent_slug')

# Check if team exists at target
if ! target_team_id=$(GH_TOKEN=$TARGET_TOKEN gh api "orgs/$target_org/teams/$slug" --jq .id 2> /dev/null) ; then
    
    # Check if source has a parent and create it if it doesn't exist or use it if it does
    if [ "$source_parent_id" != "null" ]; then

        debug "$slug has a parent [$source_parent_id] will create or using existing one at target"
        
        # Call script recursively to create parent(s)
        target_parent_id=$("DEBUG=$DEBUG $0" "$source_org" "$target_org" "$source_parent_slug" "$LOGFILE")
        
        # Set parent for the team to be created
        JSON=$(echo "$JSON" | jq --argjson parent_id "$target_parent_id" '. + {parent_team_id: $parent_id}')
    fi

    # remove parent_id and parent_slug from JSON
    JSON=$(echo "$JSON" | jq 'del(.parent_id) | del(.parent_slug)')

    debug "JSON CREATE TEAM $slug : $JSON"

    # Create team at target
    debug "creating team [$slug] at target"
    new_team_id=$(GH_TOKEN=$TARGET_TOKEN gh api --method POST "orgs/$target_org/teams" --input - <<< "$JSON" --jq .id)

    # Remove us from the team, so the team is empty
    if [ -z "$__ghuser" ]; then
        __ghuser=$(GH_TOKEN=$TARGET_TOKEN gh api user --jq '.login')
    fi
    GH_TOKEN=$TARGET_TOKEN gh api --method DELETE  "orgs/$target_org/teams/$slug/memberships/$__ghuser" --silent

    parent_desc="(no parent)"
    if [ "$source_parent_id" != "null" ]; then
        parent_desc="with parent [$source_parent_slug]"
    fi

    log "created team [$slug] at target $parent_desc"
    debug "created team [$slug] at target with parent $source_parent_slug id=[$new_team_id]"

    echo "$new_team_id"
else
    debug "Team [$slug] already exists at target [$target_team_id]. Skipping creation"
    log "Team [$slug] already exists at target. Skipping creation"

    echo "$target_team_id"
fi
