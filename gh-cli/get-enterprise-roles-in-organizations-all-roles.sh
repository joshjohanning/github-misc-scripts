#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

# results
# "viewerIsAMember": will return true if the viewer is a member of the organization
# "viewerCanAdminister": will return true if the viewer is a admin of the organization - will return true for `viewIsAMember` as well

gh api graphql --paginate -f enterpriseSlug='avocado-corp' -f query='
query ($enterpriseSlug: String!, $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
    organizations(first: 100, after: $endCursor) {
      nodes {
        name
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
