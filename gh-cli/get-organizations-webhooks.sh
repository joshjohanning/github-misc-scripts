#!/bin/bash

# gets information for all webhooks in all organizations in an enterprise

# need: `gh auth login -h github.com` and auth with a PAT!
# since the Oauth token can only receive results for hooks it created for this API call

# note: tsv is the default format
# tsv is a subset of fields, json is all fields

if [ $# -lt 1 ]
  then
    echo "usage: $0 <enterprise slug> <hostname> <format: tsv|json> > output.tsv/json"
    exit 1
fi

enterpriseslug=$1
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

organizations=$(gh api graphql --hostname $hostname --paginate -f enterpriseName="$enterpriseslug" -f query='
query getEnterpriseOrganizations($enterpriseName: String! $endCursor: String) {
  enterprise(slug: $enterpriseName) {
    organizations(first: 100, after: $endCursor) {
      nodes {
        id
        login
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '.data.enterprise.organizations.nodes[].login')

# check to see if organizations is null - null error message is confusing otherwise
if [ -z "$organizations" ] || [[ "$organizations" == *"INSUFFICIENT_SCOPES"* ]]; then
  echo -e "${RED}No organizations found for enterprise: $enterpriseslug${NC}"
  echo -e "${RED}  - Check that you have the proper scopes for enterprise with 'gh auth status' - you need at least 'read:enterprise'${NC}"
  echo -e "${RED}  - You can run 'gh auth login -h github.com' and authenticate using a PAT with the proper scopes${NC}"
  exit 1
fi

if [ "$format" == "tsv" ]; then
  echo -e "Organization\tActive\tURL\tCreated At\tUpdated At\tEvents"
fi

errors=""

for org in $organizations
do
  if [ "$format" == "tsv" ]; then
    output=$(gh api "orgs/$org/hooks" --hostname $hostname --paginate --jq ".[] | [\"$org\",.active,.config.url, .created_at, .updated_at, (.events | join(\",\"))] | @tsv" 2>&1)
  else
    output=$(gh api "orgs/$org/hooks" --hostname $hostname --paginate --jq ".[] | {organization: \"$org\", active: .active, url: .config.url, created_at: .created_at, updated_at: .updated_at, events: .events}" 2>&1)
  fi

  if [ $? -ne 0 ]; then
    errors="$errors\nError accessing organization: $org:\n$output"
  elif [ -n "$output" ]; then
    echo "$output"
  fi
done

if [ -n "$errors" ]; then
  echo -e "${RED}\nErrors encountered:\n$errors${NC}"
fi
