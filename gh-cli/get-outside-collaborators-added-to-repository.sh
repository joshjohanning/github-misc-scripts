#!/bin/bash

gh api graphql --paginate -f organizationName="joshjohanning-org" -f repoName="my-repo" -f query='
query getOutsideCollaborators($organizationName: String! $repoName: String! $endCursor: String) {
  repository(owner: $organizationName, name: $repoName) {
    id
    collaborators(first: 100, affiliation: OUTSIDE, after: $endCursor) {
      edges {
        node {
          login
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' | jq -r '.data.repository.collaborators.edges[].node.login'
