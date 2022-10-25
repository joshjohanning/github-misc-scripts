
# gh cli's token needs to be able to admin organizations - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

gh api graphql -f enterpriseName='your-enterprise-name' -f query='
query listSSOUserIdentities ($enterpriseName:String!) {
  enterprise(slug: $enterpriseName) {
    ownerInfo {
      samlIdentityProvider {
        externalIdentities(first: 100) {
          totalCount
          edges {
            node {
              guid
              samlIdentity {
                nameId
              }
              user {
                login
              }
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    }
  }
}'
