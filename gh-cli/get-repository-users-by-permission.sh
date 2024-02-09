#!/bin/bash

# this works for users added directly to repo and team
# by default, this is not cumulative; so if you query for push, you get just PUSH
#   - pass in true if you want cumulative permissions (ie: querying for PUSH would return ADMIN and MAINTAIN as well)

if [ $# -lt "2" ]; then
    echo "Usage: $0 <org/repo> <admin|maintain|push|triage|read> <cumulative-true-or-false>"
    echo "Example: ./get-repository-permissions.sh joshjohanning-org/ghas-demo admin false"
    echo "Optionally pipe the output to a file: ./get-repository-permissions.sh joshjohanning-org/ghas-demo admin false > output.csv"
    exit 1
fi

REPO=$1
PERMISSION=$2
CUMULATIVE=$3

# pass in true if you want cumulative permissions (ie: querying for PUSH would return ADMIN and MAINTAIN as well)
if [ -z "$CUMULATIVE" ]; then
    CUMULATIVE="false"
fi

echo "login,permission"

members=$(gh api --paginate "/repos/$REPO/collaborators?permission=$PERMISSION" --jq '[ .[] | { login: .login, permission: .role_name } ] | sort_by(.permission,.login) | .[] | "\(.login),\(.permission)"')

if [ "$CUMULATIVE" = "true" ]; then
    echo "$members"
else
    echo "$members" | cut -d',' -f1- | grep ",${PERMISSION}$"
fi
