#!/bin/bash

if [ $# -lt 1 ]
  then
    echo "usage: $0 <org> <format: tsv|json>" > output.csv/json
    exit 1
fi

# need: `gh auth login -h github.com` and auth with a PAT!
# sine the Oauth token can only receive results for hooks it created for this API call

auth_status=$(gh auth token 2>&1)

if [[ $auth_status == gho_* ]]
then
  echo "Token starts with gho_ - use "gh auth login" and authenticate with a PAT with read:org and admin:org_hook scope"
  exit 1
fi

export PAGER=""
org=$1
format=$2
if [ -z "$format" ]
then
  format="tsv"
fi

if [ "$format" == "tsv" ]; then
  echo -e "Organization\tActive\tURL\tCreated At\tUpdated At\tEvents"
fi

if [ "$format" == "tsv" ]; then
  gh api "orgs/$org/hooks" --paginate | jq -r --arg org "$org" '.[] | [$org,.active,.config.url, .created_at, .updated_at, (.events | join(","))] | @tsv'
else
  gh api "orgs/$org/hooks" --paginate | jq -r --arg org "$org" '.[] | {organization: $org, active: .active, url: .config.url, created_at: .created_at, updated_at: .updated_at, events: .events}'
fi
