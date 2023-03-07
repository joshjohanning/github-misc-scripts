#!/bin/bash

if [ -z "$1" ]
  then
    echo "Usage: $0 <org>"
    exit 1
fi

org=$1

gh api graphql --paginate -F owner="$org" -f query='
  query ($owner: String!, $endCursor: String) {
    organization(login: $owner) {
      repositories(first: 100, after: $endCursor) {
        nodes {
          name
          object(expression: "HEAD:.circleci/config.yml") {
            id
          }
        }
        pageInfo {
          endCursor
          hasNextPage
        }
      }
    }
  }' --jq '[ .data.organization.repositories.nodes[] | { name:.name, object: .object.id } | select(.object) | .name ] | @tsv' 
