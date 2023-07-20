#!/bin/bash

pr_states=("open" "closed" "all")

if [ $# -lt 1 ]
  then
    echo "usage: $(basename $0) <org> <pr_state>"
    exit 1
fi

org=$1
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

# get all repositories in an organization
repos=$(gh api /orgs/$org/repos --paginate)
# loop through all repos
for row in $(echo "${repos}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  repo=$(_jq '.name')
  prs=$(gh api /repos/$org/$repo/pulls?state=$pr_state\&sort=created\&direction=asc)
  echo "$prs" | jq -r '.[] | [.base.repo.full_name, .number, .title, .user.login, .state] | @tsv'
done


# prs=$(gh api /repos/$org/$repo/pulls?state=$pr_state\&sort=created\&direction=asc)

# echo "$prs" | jq -r '.[] | [.number, .title, .user.login, .state] | @tsv'
