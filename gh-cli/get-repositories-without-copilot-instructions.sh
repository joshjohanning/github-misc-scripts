#!/bin/bash

# Get repositories that do not have any Copilot custom instruction files
# Checks for the absence of both:
#   - .github/copilot-instructions.md (repository-wide custom instructions)
#   - .github/instructions/ directory (path-specific custom instructions)
#
# Usage:
#   ./get-repositories-without-copilot-instructions.sh <org>

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  exit 1
fi

org=$1

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
' --jq '.data.organization.repositories.nodes[] | select(.repoWide == null and .pathSpecific == null) | .nameWithOwner'
