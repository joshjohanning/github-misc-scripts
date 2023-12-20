#!/bin/bash

# this returns the organizations in an enterprise and the number of members in each organization
# if the user calling the script isn't a member of a particular organization, it will return 0 members

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

if [ -z "$1" ]; then
  echo "Usage: $0 <enterprise>"
  echo "Example: ./get-enterprise-roles-in-organizations-all-roles.sh avocado-corp"
  exit 1
fi

enterprise="$1"

gh api graphql --paginate -f enterpriseSlug=$enterprise -f query='
query ($enterpriseSlug: String!, $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
    organizations(first: 100, after: $endCursor) {
      nodes {
        login
        membersWithRole{
          totalCount
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}'
