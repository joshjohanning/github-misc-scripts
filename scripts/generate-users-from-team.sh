#!/bin/bash

# Usage: ./generate-users-from-team.sh <org> <team> > users.csv

if [ $# -ne "2" ]; then
    echo "Usage: $0 <org> <team>"
    exit 1
fi

org=$1
team=$2

gh api "/orgs/$org/teams/$team/members" | jq -r '.[].login'
