
# gh cli's token needs to be able to admin organizations - run this first if it can't
# gh auth refresh -h github.com -s admin:org

gh api graphql --paginate -f organizationName='joshjohanning-org-saml' -f query='
query listSSOUserIdentities($organizationName: String! $endCursor: String) {
  organization(login: $organizationName) {
    samlIdentityProvider {
      ssoUrl
      externalIdentities(first: 100, after: $endCursor) {
        totalCount
        edges {
          node {
            guid
            samlIdentity {
              nameId
              username
              givenName
              familyName
              emails {
                value
              }
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
}'
