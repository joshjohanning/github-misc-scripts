#!/bin/bash

# Usage: 
# ./get-license-usage-for-organization.sh <org>

if [ $# -lt "1" ]; then
    echo "Usage: $0 <org>"
    echo "Example: ./get-license-usage-for-organization.sh joshjohanning-org"
    echo "Optionally pipe the output to a file: ./get-license-usage-for-organization.sh joshjohanning-org > output.csv"
    exit 1
fi

ORG=$1

echo "repo,license"

gh api graphql --paginate -F owner="${ORG}" -f query='
query ($owner: String!, $endCursor: String) {
  organization(login: $owner) {
    repositories(first: 100, after: $endCursor) {
      nodes {
        name
        licenseInfo {
          name
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '[ .data.organization.repositories.nodes[] | { name:.name, license: .licenseInfo.name } ]' | jq -r '.[] | "\(.name),\(.license)"'
