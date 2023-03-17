
#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

gh api graphql --paginate -f enterpriseSlug='avocado-corp'  -f query='
query ($enterpriseSlug: String!,  $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
    members(first: 100, role: OWNER, after: $endCursor) {
      nodes {
        ... on EnterpriseUserAccount {
            login
            name
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}'
