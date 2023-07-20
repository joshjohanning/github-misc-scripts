#!/bin/bash

pr_states=("open" "closed" "all")

if [ $# -lt 2 ]
  then
    echo "usage: $(basename $0) <org> <repo> <pr_state>"
    exit 1
fi

org=$1
repo=$2
pr_state=$3

# set the default for pr_status to be all
if [ -z "$pr_state" ]
  then
    pr_state="all"
fi

if [[ ! " ${pr_states[*]} " =~  ${pr_state}  ]]
  then
    echo "pr_state must be one of: ${pr_states[*]}"
    exit 1
fi

prs=$(gh api /repos/$org/$repo/pulls?state=$pr_state\&sort=created\&direction=asc --paginate)

echo "$prs" | jq -r '.[] | [.base.repo.full_name, .number, .title, .user.login, .state] | @tsv'
