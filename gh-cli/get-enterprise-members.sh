#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

if [ -z "$1" ]; then
  echo "Usage: $0 <enterprise> <hostname>"
  echo "Example: ./get-enterprise-members.sh avocado-corp github.com"
  exit 1
fi

enterprise="$1"
hostname=${2:-"github.com"}

gh api graphql --hostname $hostname --paginate -f enterpriseSlug=$enterprise -f query='
query ($enterpriseSlug: String!,  $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
    members(first: 100, after: $endCursor) {
      nodes {
        ... on EnterpriseUserAccount {
            login
            name
            user {
              email
            }
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}'
