#!/bin/bash

# gets a list of organizations for a given enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

if [ -z "$1" ]; then
  echo "Usage: $(basename $0) <enterprise-slug> <hostname>"
  exit 1
fi

enterpriseslug=$1
hostname=${2:-"github.com"}
export PAGER=""

# Define color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

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
}' --jq '{organizations: [.data.enterprise.organizations.nodes[].login]}')

# Slurp and merge JSON objects
merged_organizations=$(echo "$organizations" | jq -s '{organizations: map(.organizations) | add}')

# Print the consolidated JSON object
echo "$merged_organizations" | jq .

# check to see if organizations is null - null error message is confusing otherwise
if [ -z "$organizations" ] || [[ "$organizations" == *"INSUFFICIENT_SCOPES"* ]]; then
  echo -e "${RED}No organizations found for enterprise: $enterpriseslug${NC}"
  echo -e "${RED}  - Check that you have the proper scopes for enterprise with 'gh auth status' - you need at least 'read:enterprise'${NC}"
  echo -e "${RED}  - You can run 'gh auth refresh -h github.com -s read:org -s read:enterprise' to add the scopes${NC}"
  echo -e "${RED}  - Or you can run 'gh auth login -h github.com' and authenticate using a PAT with the proper scopes${NC}"
  exit 1
fi
