#!/bin/bash

# adds (or invites) a collaborator to a repository

permissions=("pull" "triage" "push" "maintain" "admin")
# corresponds to read, triage, write, maintain, admin

if [ $# -ne 4 ]
  then
    echo "usage: $(basename $0) <org> <repo> <role> <login>"
    exit 1
fi

org=$1
repo=$2
role=$3
login=$4

if [[ ! " ${permissions[*]} " =~  ${role}  ]]
  then
    echo "permission must be one of: ${permissions[*]}"
    exit 1
fi

# https://docs.github.com/en/rest/collaborators/collaborators?apiVersion=2022-11-28#add-a-repository-collaborator
gh api --method PUT "repos/$org/$repo/collaborators/$login" -f permission="$role"
