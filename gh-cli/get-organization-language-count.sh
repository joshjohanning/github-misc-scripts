#!/bin/bash

# Usage: ./get-organization-language-count.sh <org>

if [ -z "$1" ]; then
    echo "Usage: $0 <org>"
    exit 1
fi

org=$1

results=$(gh api graphql --paginate -F owner="$org" -f query='
query ($owner: String!, $endCursor: String) {
  organization(login: $owner) {
    repositories(first: 100, after: $endCursor) {
      totalCount
      nodes {
        nameWithOwner
        languages(first: 1) {
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
}')

echo $results >> results.json
# sum the nodes.name
echo $results | jq -r '.data.organization.repositories.nodes[].languages.nodes[].name' | sort | uniq -c | sort -nr
