#!/bin/bash

# gh cli's token needs to be able to admin organization - run this first if it can't
# gh auth refresh -h github.com -s admin:org

if [ $# -lt "1" ]; then
    echo "Usage: $0 <organization>"
    exit 1
fi

org=$1

gh api graphql --paginate -f organizationName="$org" -f query='
query getOrganizationIpAllowList($organizationName: String! $endCursor: String) {
  organization(login: $organizationName) {
    ipAllowListEntries(first: 100, after: $endCursor) {
      nodes {
        id
        allowListValue
        name
        isActive
        createdAt
        updatedAt
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '.data.organization.ipAllowListEntries.nodes[] | [.id, .allowListValue, .name, .isActive, .createdAt, .updatedAt] | @tsv' 
