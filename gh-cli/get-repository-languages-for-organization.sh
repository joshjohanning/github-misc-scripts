#!/bin/bash

# Usage: 
# ./get-repository-languages-for-organization.sh <org>

if [ $# -lt "1" ]; then
    echo "Usage: $0 <org> [<top-x-number-languages-defaults-to-1>]"
    echo "Example: ./get-repository-languages-for-organization.sh joshjohanning-org 1"
    echo "Optionally pipe the output to a file: ./get-repository-languages-for-organization.sh joshjohanning-org > output.csv"
    exit 1
fi

ORG=$1
TOP=$2

# default TOP to 1 if not set
if [ -z "$TOP" ]
  then
    TOP=1
fi

echo "repo,language"

gh api graphql --paginate -F owner="${ORG}" -F top=$TOP -f query='
query ($owner: String!, $top: Int!, $endCursor: String) {
  organization(login: $owner) {
    repositories(first: 100, after: $endCursor) {
      nodes {
        name
        languages(first: $top, orderBy: {direction: DESC, field: SIZE}) {
          nodes {
            name
          }
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '[ .data.organization.repositories.nodes[] | { name:.name, languages: .languages.nodes } ]' | jq -r '.[] | "\(.name),\(.languages[].name)"'
