#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

if [ $# -lt "1" ]; then
    echo "Usage: $0 <enterprise-slug>"
    exit 1
fi

enterprise=$1

gh api graphql --paginate -f enterpriseName="$enterprise" -f query='
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
}' --jq '.data.enterprise.ownerInfo.ipAllowListEntries.nodes[] | [.id, .allowListValue, .name, .isActive, .createdAt, .updatedAt] | @tsv'
