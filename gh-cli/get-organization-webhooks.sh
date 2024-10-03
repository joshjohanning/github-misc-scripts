#!/bin/bash

# gets information for all webhooks for in an organization

# need: `gh auth login -h github.com` and auth with a PAT!
# since the Oauth token can only receive results for hooks it created for this API call

# note: tsv is the default format
# tsv is a subset of fields, json is all fields

if [ $# -lt 1 ]
  then
    echo "usage: $0 <org> <hostname> <format: tsv|json> > output.tsv/json"
    exit 1
fi

org=$1
hostname=${2:-"github.com"}
format=${3:-"tsv"}
export PAGER=""

# Define color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

auth_status=$(gh auth token -h $hostname 2>&1)

if [[ $auth_status == gho_* ]]
then
  echo -e "${RED}Token is an OAuth that starts with \"gho_\" which won't work for this request. To resolve, either:${NC}"
  echo -e "${RED}  1. use \"gh auth login\" and authenticate with a PAT with \"read:org\" and \"admin:org_hook\" scope${NC}"
  echo -e "${RED}  2. set an environment variable \"GITHUB_TOKEN=your_PAT\" using a PAT with \"read:org\" and \"admin:org_hook\" scope${NC}"
  exit 1
fi

if [ "$format" == "tsv" ]; then
  echo -e "Organization\tActive\tURL\tCreated At\tUpdated At\tEvents"
fi

if [ "$format" == "tsv" ]; then
  gh api "orgs/$org/hooks" --hostname $hostname --paginate --jq ".[] | [\"$org\",.active,.config.url, .created_at, .updated_at, (.events | join(\",\"))] | @tsv"
else
  gh api "orgs/$org/hooks" --hostname $hostname --paginate --jq ".[] | {organization: \"$org\", active: .active, url: .config.url, created_at: .created_at, updated_at: .updated_at, events: .events}"
fi
