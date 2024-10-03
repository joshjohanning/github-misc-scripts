#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

if [ $# -lt "1" ]; then
    echo "Usage: $0 <enterprise>"
    exit 1
fi

enterprise="$1"

gh api graphql --paginate -f enterpriseName="$enterprise" -f query='
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
