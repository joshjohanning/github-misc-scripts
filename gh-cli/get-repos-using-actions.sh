#!/bin/bash

if [ -z "$1" ]
  then
    echo "Usage: $0 <org>"
    exit 1
fi

org=$1

gh api graphql --paginate -F owner="$org" -f query='
  query ($owner: String!, $endCursor: String = null) {
    organization(login: $owner) {
      repositories(
        first: 100
        orderBy: { field: NAME, direction: ASC }
        after: $endCursor
      ) {
        totalCount
        pageInfo {hasNextPage endCursor}
        nodes {
          name
          object(expression: "HEAD:.github/workflows/") {
            ... on Tree {
              entries {
                path
              }
            }
          }
        }
      }
    }
  }
' --jq '.data.organization.repositories.nodes[] | select(.object != null) | .name'
