#!/bin/bash

# gh cli's token needs to be able to admin org - run this first if it can't
# gh auth refresh -h github.com -s admin:org

# affiliation can be: OUTSIDE, DIRECT, ALL

# returns the permission for everyone who can access the repo and how they access it (direct, team, org)

gh api graphql --paginate -f owner='joshjohanning-org' -f repo='ghas-demo' -f affiliation='ALL' -f query='
query ($owner: String!, $repo: String!, $affiliation: CollaboratorAffiliation!, $endCursor: String) {
  repository(owner:$owner, name:$repo) {
    name
    owner {
      login
    }
    collaborators(first: 100, affiliation: $affiliation, after: $endCursor) {
      pageInfo {
        endCursor
        hasNextPage
      }
      edges {
        node {
          login
        }
        permission
        permissionSources {
          permission
          source {
            ... on Team {
              type: __typename
              name: slug
            }
            ... on Repository {
              type: __typename
              name: name
            }
            ... on Organization {
              type: __typename
              name: login
            }
          }
        }
      }
    }
  }
}'
