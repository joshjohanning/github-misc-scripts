#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $(basename $0) <enterprise-slug>"
  exit 1
fi

enterpriseslug=$1

organizations=$(gh api graphql --paginate -f enterpriseName="$enterpriseslug" -f query='
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
if [ -z "$organizations" ]
then
  # Define color codes
  RED='\033[0;31m'
  NC='\033[0m' # No Color

  # Print colored messages
  echo -e "${RED}No organizations found for enterprise: $enterpriseslug${NC}"
  echo -e "${RED}Check that you have the proper scopes for enterprise, e.g.: 'gh auth refresh -h github.com -s read:org -s read:enterprise'${NC}"
  exit 1
fi
