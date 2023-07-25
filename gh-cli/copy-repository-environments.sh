#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 <source org> <source_repo> <target org> [target_repo]"
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
source_repo=$2
target_org=$3
target_repo=${4:-$source_repo}

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

function getReviewersLogins() {
    local source_org=$1
    local target_org=$2
    local reviewers_json=$3
}

GH_TOKEN=$SOURCE_TOKEN gh api --paginate "repos/$source_org/$source_repo/environments" -H "X-GitHub-Api-Version: 2022-11-28" --jq '.environments.[].name' | while read -r environment_name; do

    environment_json=$(GH_TOKEN=$SOURCE_TOKEN gh api "repos/$source_org/$source_repo/environments/$environment_name" \
        --jq '{protection_rules,can_admins_bypass,deployment_branch_policy }')

    echo "Creating or updating environment: $environment_name"

    can_admins_bypass=$(jq -r '.can_admins_bypass' <<<"$environment_json")
    payload=$(jq -c --argjson can_admins_bypass "$can_admins_bypass" '{"can_admins_bypass": $can_admins_bypass}' <<<"{}")

    # check if there is a wait wait
    wait_timer=$(jq -r '.protection_rules[] | select(.type == "wait_timer") | .wait_timer' <<<"$environment_json")

    if [ -n "$wait_timer" ]; then
        # append to payload
        payload=$(jq -c --argjson wait_timer "$wait_timer" '.wait_timer = $wait_timer' <<<"$payload")
    fi

    # check if there is a reviewers
    reviewers=$(jq -c '.protection_rules[] | select(.type == "required_reviewers") | .reviewers' <<<"$environment_json")
    if [ -n "$reviewers" ]; then
        reviewers_json="[]"
        while read -r reviewer_json; do

            reviewer_type=$(jq -r '.type' <<<"$reviewer_json")

            #check if reviewer is a team
            if [ "$reviewer_type" = "Team" ]; then
                reviewer_slug=$(jq -r '.reviewer.slug' <<<"$reviewer_json")

                # check if team has access to repo
                reviewer_id=$(GH_TOKEN=$TARGET_TOKEN gh api "orgs/$target_org/teams/$reviewer_slug" --jq '.id')

                if [ $? != 0 ]; then
                    echo "    ERROR: Team $reviewer_slug does not exist at target org $target_org. Ignoring it."
                else
                    if ! GH_TOKEN=$TARGET_TOKEN gh api \
                        "orgs/$target_org/teams/$reviewer_slug/repos/$target_org/$target_repo" \
                        -H "X-GitHub-Api-Version: 2022-11-28" --silent >/dev/null 2>&1; then
                        echo "    ERROR: Team $reviewer_slug does not have access to repo $target_org/$target_repo. Ignoring it."
                    else
                        echo "    Adding team $reviewer_slug to reviewers"
                        reviewers_json=$(jq -c --argjson reviewer_id "$reviewer_id" '. += [{"type": "Team", "id": $reviewer_id}]' <<<"$reviewers_json")
                    fi
                fi
            fi

            # if reviewer is a user
            if [ "$reviewer_type" = "User" ]; then
                # get user id at the target
                reviewer_login=$(jq -r '.reviewer.login' <<<"$reviewer_json")

                if [ -n "$MAP_USER_SCRIPT" ]; then
                    reviewer_login=$($MAP_USER_SCRIPT "$reviewer_login")
                fi

                reviewer_id=$(GH_TOKEN=$TARGET_TOKEN gh api "orgs/$target_org/memberships/$reviewer_login" --jq '.user.id')

                if [ $? != 0 ]; then
                    echo "ERROR: User $reviewer_login does not exist at target org $target_org. Ignoring it."
                else
                    echo "    Adding user $reviewer_login to reviewers"
                    reviewers_json=$(jq -c --argjson reviewer_id "$reviewer_id" '. += [{"type": "User", "id": $reviewer_id}]' <<<"$reviewers_json")
                fi
            fi

        done < <(jq -c '.[]' <<<"$reviewers")

        # append to payload
        payload=$(jq -c --argjson "reviewers_json" "$reviewers_json" '. += {"reviewers": $reviewers_json}' <<<"$payload")
    fi

    deployment_branch_policy=$(jq -c '.deployment_branch_policy' <<<"$environment_json")
    if [ -n "$deployment_branch_policy" ]; then
        payload=$(jq -c --argjson deployment_branch_policy "$deployment_branch_policy" '. += {"deployment_branch_policy": $deployment_branch_policy}' <<<"$payload")
    fi

    GH_TOKEN=$TARGET_TOKEN gh api --silent --method PUT \
        "repos/$target_org/$target_repo/environments/$environment_name" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --input - <<<"$payload"

    # We only support branch policies
    # https://docs.github.com/pt/rest/deployments/branch-policies?apiVersion=2022-11-28
    if [ "$deployment_branch_policy" != "null" ]; then
        while read -r branch_name; do
            echo "    Creating branch policy for $branch_name"
            if ! GH_TOKEN=$TARGET_TOKEN gh api \
                --method POST \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "repos/$target_org/$target_repo/environments/$environment_name/deployment-branch-policies" \
                -f name="$branch_name" --silent; then
                echo "    Error: Failed to create branch policy for $branch_name"
            fi
        done < <(GH_TOKEN=$SOURCE_TOKEN gh api --paginate \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "repos/$source_org/$source_repo/environments/$environment_name/deployment-branch-policies" --jq .branch_policies[].name)
    fi

done
