#!/bin/bash

# note: this is a bit of a hack; there is no direct way to pull users added directly to repositories
# note: custom repository roles will show up as the base permission role
# credits @kenmuse

gh api graphql -F org="joshjohanning-org" -f query='
query ($org: String!) {
  organization(login: $org) {
    repositories(first: 100) {
      pageInfo{
        hasNextPage
        endCursor
      }
      nodes {
        name
        collaborators(first: 100, affiliation:DIRECT) {
          pageInfo{
                hasNextPage
                endCursor
          }
          edges {
            permissionSources {
              permission
              source {
                ... on Repository {
                  nameWithOwner
                  repoName: name
                }
              }
            }
            node {
              userHandle: login
            }
          }
        }
      }
    }
  }
}' --template '{{range .data.organization.repositories.nodes}}{{ $repo:= .name }}{{range .collaborators.edges }}{{ $handle := .node.userHandle }}"{{ $repo }}", "{{ $handle }}", {{ range .permissionSources }}{{ $permission := .permission }}{{ with .source.repoName }}"{{ $permission }}"{{ break }}{{ end }}{{ end }}{{ println }}{{ end }}{{ end }}' 
