#!/bin/bash

if [ $# -ne 2 ]; then
    echo "usage: $0 <source org> <target org>"
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

if [ "$source_org" = "$target_org" ]; then
    echo "source org and target org must be different"
    exit 1
fi

# read all target teams and loop
GH_TOKEN=$TARGET_TOKEN gh api --paginate "orgs/$target_org/teams" --jq '.[] | [.slug, .parent.id] | @tsv' | while read -r slug target_parent_id; do

    echo "Analyzing team [$slug]"

    # check if team exists at source
    if ! source_team=$(GH_TOKEN=$SOURCE_TOKEN gh api "orgs/$source_org/teams/$slug" --jq '{slug: .slug, parent_slug: (.parent.slug // "")}' 2>/dev/null); then
        echo "  Team [$slug] does not exist at source. Skipping"
        continue
    else
        source_parent_slug=$(echo "$source_team" | jq -r '.parent_slug')

        if [ -z "$source_parent_slug" ] && [ -n "$target_parent_id" ]; then
            # remove parent from target team
            echo "  Removing parent from [$slug]"
            GH_TOKEN=$TARGET_TOKEN gh api -X PATCH "orgs/$target_org/teams/$slug" \
                -F parent_team_id="null" \
                --silent
        elif [ -n "$source_parent_slug" ]; then            
            # add/set parent to target team

            if ! parent_id=$(GH_TOKEN=$TARGET_TOKEN gh api "orgs/$target_org/teams/$source_parent_slug" --jq '.id' 2> /dev/null) ; then
                echo "  Parent [$source_parent_slug] does not exist at target. Skipping"
                if [ -n "$target_parent_id" ]; then
                    echo "  Warning: [$slug] may be in an ambiguous state because it has a parent [$target_parent_id] but the parent does not exist at target"
                fi
                continue
            fi

            if [ "$parent_id" == "$target_parent_id" ]; then
                echo "  Parent is already set. Skipping"
                continue
            fi

            echo "  Adding/set parent [$source_parent_slug] to [$slug]"
            GH_TOKEN=$TARGET_TOKEN gh api -X PATCH "orgs/$target_org/teams/$slug" \
                -F parent_team_id="$parent_id" \
                -f privacy=closed \
                --silent
        else
            echo "  No parent to set/clean. Skipping"
        fi
    fi
done
