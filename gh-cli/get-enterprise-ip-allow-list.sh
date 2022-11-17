#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

gh api graphql --paginate -f enterpriseName='my-enterprise' -f query='
query getEnterpriseIpAllowList($enterpriseName: String! $endCursor: String) {
  enterprise(slug: $enterpriseName) {
    ownerInfo {
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
  }
}'
