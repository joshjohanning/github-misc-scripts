#!/bin/bash

# gets the settings for all organizations in an enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

# note: tsv is the default format
# tsv is a subset of fields, json is all fields

if [ $# -lt 1 ]
  then
    echo "usage: $0 <enterprise-slug> <hostname> <format: tsv|json> > output.tsv/json"
    exit 1
fi

enterpriseslug=$1
hostname=${2:-"github.com"}
format=${3:-"tsv"}
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
}' --jq '.data.enterprise.organizations.nodes[].login')

# check to see if organizations is null - null error message is confusing otherwise
if [ -z "$organizations" ] || [[ "$organizations" == *"INSUFFICIENT_SCOPES"* ]]; then
  echo -e "${RED}No organizations found for enterprise: $enterpriseslug${NC}"
  echo -e "${RED}  - Check that you have the proper scopes for enterprise with 'gh auth status' - you need at least 'read:enterprise'${NC}"
  echo -e "${RED}  - You can run 'gh auth refresh -h github.com -s read:org -s read:enterprise' to add the scopes${NC}"
  echo -e "${RED}  - Or you can run 'gh auth login -h github.com' and authenticate using a PAT with the proper scopes${NC}"
  exit 1
fi

if [ "$format" == "tsv" ]; then
  echo -e "Organization Login\tDisplay Name\tDescription\tDefault Repo Permission\tMembers Can Create Repos\t\tMembers Allowed Repos Creation Type\tMembers Can Create Public Repos\tMembers Can Create Private Repos\tMembers Can Create Internal Repos\tMembers Can Fork Private Repos"
fi

errors=""

for org in $organizations
do
  if [ "$format" == "tsv" ]; then
    output=$(gh api "orgs/$org" --hostname $hostname --jq ". | [\"$org\", .name, .description, .default_repository_permission, .members_can_create_repositories, .members_allowed_repository_creation_type, .members_can_create_public_repositories, .members_can_create_private_repositories, .members_can_create_internal_repositories, .members_can_fork_private_repositories] | @tsv" 2>&1)
  else
    output=$(gh api "orgs/$org" --hostname $hostname 2>&1)
  fi

  if [ $? -ne 0 ] || [[ ! "$output" =~ "true" ]] && [[ ! "$output" =~ "false" ]]; then
    if [ "$format" == "tsv" ]; then
      output=$(echo -e "$output" | tr -d '\t')
      output+=" - (you may not have admin access to the org)"
    fi
    errors="$errors\nError accessing organization: $org:\n$output"
    if [ "$format" == "tsv" ]; then
      echo -e "$org\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a"
    else
      echo -e "$org,n/a,n/a,n/a,n/a,n/a,n/a,n/a,n/a,n/a"
    fi
  else
    if [ -n "$output" ]; then
      echo "$output"
    fi
  fi
done

if [ -n "$errors" ]; then
  echo -e "${RED}\nErrors encountered:\n$errors${NC}"
fi
