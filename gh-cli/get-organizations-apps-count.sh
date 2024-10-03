#!/bin/bash

# gets the installed app count for all organizations in an enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

# note: format is tsv

if [ $# -lt 1 ]
  then
    echo "usage: $0 <enterprise-slug> <hostname> > output.tsv"
    exit 1
fi

export PAGER=""
enterpriseslug=$1
hostname=${2:-"github.com"}

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

echo -e "Org\tApp Count"

errors=""

for org in $organizations
do
  output=$(gh api "orgs/$org/installations" --hostname $hostname --jq ". | [\"$org\", .total_count] | @tsv" 2>&1)

  if [ $? -ne 0 ]; then
    errors="$errors\nError accessing organization: $org:\n$output"
    echo -e "$org\tn/a"
  else
    echo "$output"
  fi
done

if [ -n "$errors" ]; then
  echo -e "${RED}\nErrors encountered:\n$errors${NC}"
fi