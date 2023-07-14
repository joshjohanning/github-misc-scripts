#!/bin/bash
if [ $# -ne 1 ]
  then
    echo "usage: $0 <org>"
    exit 1
fi
org=$1
export PAGER=""
gh api "orgs/$org/repos" --paginate --jq .[].name | while read -r repo; 
do
    gh api "repos/$org/$repo/hooks" | jq -r --arg repo "$repo" '.[] | [$repo,.active,.config.url, .config.secret] | @tsv'
done