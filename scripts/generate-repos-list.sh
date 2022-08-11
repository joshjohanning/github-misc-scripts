#!/bin/bash

# Usage: ./generate-repos.sh <org> > csv.csv

# Credits to @tspascoal from this repo: https://github.com/tspascoal/dependabot-alerts-helper

if [ -z "$1" ]; then
    echo "Usage: $0 <org>"
    exit 1
fi

org=$1

gh api graphql --paginate -F org="$org" -f query='query($org: String!$endCursor: String){
organization(login:$org) {
    repositories(first:100,after: $endCursor) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        owner {
          login
        }
        name
      }
    }
  }
}' --template '{{range .data.organization.repositories.nodes}}{{printf "%s/%s\n" .owner.login .name}}{{end}}'
