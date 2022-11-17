
# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

gh api graphql --paginate -f enterpriseName='your-enterprise-name' -f query='
query listSSOUserIdentities ($enterpriseName:String! $endCursor: String) {
  enterprise(slug: $enterpriseName) {
    ownerInfo {
      samlIdentityProvider {
        externalIdentities(first: 100, after: $endCursor) {
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
