#!/bin/bash

# gh cli's token needs to be able to admin organization - run this first if it can't
# gh auth refresh -h github.com -s admin:org

gh api graphql --paginate -f organizationName='my-org' -f query='
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
}'
