#!/bin/bash

# gets the installed apps and their details for all organizations in an enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

# note: tsv is the default format
# tsv is a subset of fields, json is all fields

if [ $# -lt 1 ]
  then
    echo "usage: $0 <enterprise-slug> <hostname> <format: tsv|json> > output.tsv"
    exit 1
fi

enterpriseslug=$1
hostname=${2:-"github.com"}
format=${3:-"tsv"}
export PAGER=""

# Define color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

organizations=$(gh api graphql --paginate --hostname $hostname -f enterpriseName="$enterpriseslug" -f query='
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
  echo -e "${RED}  - You can run 'gh auth refresh -h github.com -s read:org -s read:enterprise' to add the scopes${NC}"
  echo -e "${RED}  - Or you can run 'gh auth login -h github.com' and authenticate using a PAT with the proper scopes${NC}"
  exit 1
fi

errors=""

if [ "$format" == "tsv" ]; then
  echo -e "Org\tApp Slug\tApp ID\tCreated At\tUpdated At\tPermissions\tEvents"
fi

for org in $organizations
do
  if [ "$format" == "tsv" ]; then
    output=$(gh api "orgs/$org/installations" --hostname $hostname --jq ".installations[] | [\"$org\", .app_slug, .app_id, .created_at, .updated_at, (.permissions | join(\",\")), (if .events | length == 0 then \"null\" else .events | join(\",\") end)] | @tsv" 2>&1)
  else
    output=$(gh api "orgs/$org/installations" --hostname $hostname --jq '.installations[]' 2>&1)
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
