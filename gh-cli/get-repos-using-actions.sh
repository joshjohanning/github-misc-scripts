#!/bin/bash

gh api graphql --paginate -F owner='joshjohanning-org' -f query='
  query ($owner: String!, $endCursor: String = null) {
    organization(login: $owner) {
      repositories(
        first: 100
        orderBy: { field: NAME, direction: ASC }
        after: $endCursor
      ) {
        totalCount
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
