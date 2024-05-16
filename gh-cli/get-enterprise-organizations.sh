#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $(basename $0) <enterprise-slug>"
  exit 1
fi

enterpriseslug=$1

gh api graphql --paginate -f enterpriseName="$enterpriseslug" -f query='
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
}' --jq '{organizations: [.data.enterprise.organizations.nodes[].login]}'