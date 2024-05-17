#!/bin/bash

# gets information for all webhooks for in an organization

# need: `gh auth login -h github.com` and auth with a PAT!
# since the Oauth token can only receive results for hooks it created for this API call

if [ $# -lt 1 ]
  then
    echo "usage: $0 <org> <hostname> <format: tsv|json> > output.tsv/json"
    exit 1
fi

org=$1
hostname=$2
format=$3
export PAGER=""

# set hostname to github.com by default
if [ -z "$hostname" ]
then
  hostname="github.com"
fi

auth_status=$(gh auth token -h $hostname 2>&1)

if [[ $auth_status == gho_* ]]
then
  echo "Token starts with gho_ - use "gh auth login" and authenticate with a PAT with read:org and admin:org_hook scope"
  exit 1
fi

if [ -z "$format" ]
then
  format="tsv"
fi

if [ "$format" == "tsv" ]; then
  echo -e "Organization\tActive\tURL\tCreated At\tUpdated At\tEvents"
fi

if [ "$format" == "tsv" ]; then
  gh api "orgs/$org/hooks" --hostname $hostname --paginate --jq ".[] | [\"$org\",.active,.config.url, .created_at, .updated_at, (.events | join(\",\"))] | @tsv"
else
  gh api "orgs/$org/hooks" --hostname $hostname --paginate --jq ".[] | {organization: \"$org\", active: .active, url: .config.url, created_at: .created_at, updated_at: .updated_at, events: .events}"
fi
