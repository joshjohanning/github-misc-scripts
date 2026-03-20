#!/bin/bash

# Get repositories that have Copilot custom instruction files
# Checks for:
#   - .github/copilot-instructions.md (repository-wide custom instructions)
#   - .github/instructions/ directory (path-specific custom instructions)
#
# Usage:
#   ./get-repositories-with-copilot-instructions.sh <org>
# # If you want to in a nicely formatted table, you can pipe the output to `column`:
#   ./get-repositories-with-copilot-instructions.sh <org> | column -ts $'\t'

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  exit 1
fi

org=$1

echo -e "Repository\tRepo-Wide\tPath-Specific Files"

gh api graphql --paginate -F owner="$org" -H "X-Github-Next-Global-ID: 1" -f query='
  query ($owner: String!, $endCursor: String = null) {
    organization(login: $owner) {
      repositories(
        first: 100
        orderBy: { field: NAME, direction: ASC }
        after: $endCursor
      ) {
        totalCount
        pageInfo {hasNextPage endCursor}
        nodes {
          nameWithOwner
          repoWide: object(expression: "HEAD:.github/copilot-instructions.md") {
            ... on Blob {
              byteSize
            }
          }
          pathSpecific: object(expression: "HEAD:.github/instructions/") {
            ... on Tree {
              entries {
                path
              }
            }
          }
        }
      }
    }
  }
' --jq '.data.organization.repositories.nodes[] | select(.repoWide != null or .pathSpecific != null) | [.nameWithOwner, (if .repoWide != null then "yes" else "no" end), (if .pathSpecific != null then (.pathSpecific.entries | length | tostring) else "0" end)] | @tsv'
