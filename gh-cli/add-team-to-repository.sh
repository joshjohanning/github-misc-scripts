#!/bin/bash

permissions=("pull" "triage" "push" "maintain" "admin")

if [ $# -ne 4 ]
  then
    echo "usage: $0 <org> <repo> <team slug> <permission>"
    echo "permission can be one of: ${permissions[*]}"
    exit 1
fi

org=$1
repo=$2
team=$3
permission=$4

if [[ ! " ${permissions[*]} " =~  ${permission}  ]]
  then
    echo "permission must be one of: ${permissions[*]}"
    exit 1
fi

# https://docs.github.com/en/rest/teams/teams?apiVersion=2022-11-28#add-or-update-team-repository-permissions

gh api --method PUT "orgs/$org/teams/$team/repos/$org/$repo" -f permission="$permission"
