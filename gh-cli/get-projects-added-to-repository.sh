#!/bin/bash

# needs: gh auth login -s read:project

if [ -z "$2" ]
  then
    echo "Usage: $0 <org> <repository>"
    exit 1
fi

org=$1
repo=$2

gh api graphql --paginate -f organization="$org" -f repository="$repo" -f query='
  query ($organization: String!) {
    organization (login: $organization) {
      login
      repository (name: "cisco-cxepi") {
        name
        projectsV2 (first: 100) {
          totalCount
          nodes {
            title
            shortDescription
            id
            url
            number
            updatedAt
            creator {
              login
            }
            closed
            closedAt
            repositories (first: 100) {
              totalCount
              nodes {
                name
              }
            }
            items {
              totalCount
            }
            views {
              totalCount
            }
          }
        }
      }
    }
  }
'
