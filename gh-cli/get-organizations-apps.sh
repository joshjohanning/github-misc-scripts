#!/bin/bash

# gets the settings for all organizations in an enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

# note: tsv is the default format
# tsv is a subset of fields, json is all fields

if [ $# -lt 1 ]
  then
    echo "usage: $0 <enterprise-slug> <hostname> <format: tsv|json> > output.tsv"
    exit 1
fi

enterpriseslug=$1
hostname=$2
format=$3
export PAGER=""

# set hostname to github.com by default
if [ -z "$hostname" ]
then
  hostname="github.com"
fi

if [ -z "$format" ]
then
  format="tsv"
fi

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
if [ -z "$organizations" ] || [ $? -ne 0 ]
then
  # Define color codes
  RED='\033[0;31m'
  NC='\033[0m' # No Color

  # Print colored messages
  echo -e "${RED}No organizations found for enterprise: $enterpriseslug${NC}"
  echo -e "${RED}Check that you have the proper scopes for enterprise, e.g.: 'gh auth refresh -h github.com -s read:org -s read:enterprise'${NC}"
  exit 1
fi

if [ "$format" == "tsv" ]; then
  echo -e "Org\tApp Slug\tApp ID\tCreated At\tUpdated At\tPermissions\tEvents"
fi

for org in $organizations
do
  if [ "$format" == "tsv" ]; then
    gh api "orgs/$org/installations" --hostname $hostname --jq ".installations[] | [\"$org\", .app_slug, .app_id, .created_at, .updated_at, (.permissions | join(\",\")), (if .events | length == 0 then \"null\" else .events | join(\",\") end)] | @tsv"
  else
    gh api "orgs/$org/installations" --hostname $hostname --jq '.installations[]'
  fi
done
