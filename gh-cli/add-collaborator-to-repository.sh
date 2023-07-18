#!/bin/bash

permissions=("pull" "triage" "push" "maintain" "admin")

if [ $# -ne 4 ]
  then
    echo "usage: $(basename $0) <org> <repo> <login> <role>"
    exit 1
fi

org=$1
repo=$2
login=$3
role=$4

if [[ ! " ${permissions[*]} " =~  ${role}  ]]
  then
    echo "permission must be one of: ${permissions[*]}"
    exit 1
fi

# https://docs.github.com/en/rest/collaborators/collaborators?apiVersion=2022-11-28#add-a-repository-collaborator
gh api --method PUT "repos/$org/$repo/collaborators/$login" -f permission="$role"
