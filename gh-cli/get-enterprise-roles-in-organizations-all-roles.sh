#!/bin/bash

# this gets the enterprise roles for the current user, e.g. which organizations they are a member/owner of

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

# results
# "viewerIsAMember": will return true if the viewer is a member of the organization
# "viewerCanAdminister": will return true if the viewer is a admin of the organization - will return true for `viewIsAMember` as well

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
        viewerIsAMember
        viewerCanAdminister
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}'
