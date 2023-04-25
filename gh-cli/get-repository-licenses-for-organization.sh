#!/bin/bash

# Usage: 
# ./get-license-usage-for-organization.sh <org> <output_filename>

if [ $# -lt "1" ]; then
    echo "Usage: $0 <org> <output_filename>"
    echo "Example: ./get-license-usage-for-organization.sh joshjohanning-org > output.csv"

    exit 1
fi

ORG=$1
# OUTPUT=$2

# mv output.log if it exists
# if [ -f "$OUTPUT" ]; then
#     date=$(date +"%Y-%m-%d %T")
#     mv $OUTPUT "$OUTPUT-$date.csv"
# fi

echo "repo,license" # > $OUTPUT

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
}' --jq '[ .data.organization.repositories.nodes[] | { name:.name, license: .licenseInfo.name } ]' | jq -r '.[] | "\(.name),\(.license)"' # >> $OUTPUT
