#!/bin/bash

# gh cli's token needs to be able to admin organizations - run this first if it can't
# gh auth refresh -h github.com -s admin:org

if [ $# -lt "1" ]; then
    echo "Usage: $0 <org>"
    exit 1
fi

org="$1"

gh api graphql --paginate -f organizationName="$org" -f query='
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
