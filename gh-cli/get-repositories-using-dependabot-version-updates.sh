#!/bin/bash

# Get repositories using Dependabot version updates
# This script finds all repositories in an organization that have a .github/dependabot.yml file
# Usage: ./get-repositories-using-dependabot-version-updates.sh <org>

if [ -z "$1" ]
  then
    echo "Usage: $0 <org>"
    echo "Example: ./get-repositories-using-dependabot-version-updates.sh my-org"
    exit 1
fi

org=$1

echo "🔍 Searching for repositories with Dependabot configuration in '$org'..."
echo ""

repositories=$(gh api graphql --paginate -F owner="$org" -f query='
  query ($owner: String!, $endCursor: String) {
    organization(login: $owner) {
      repositories(first: 100, after: $endCursor) {
        nodes {
          name
          object(expression: "HEAD:.github/dependabot.yml") {
            id
          }
        }
        pageInfo {
          endCursor
          hasNextPage
        }
      }
    }
  }' --jq '.data.organization.repositories.nodes[] | select(.object) | .name' | tr -d '"')

if [ -z "$repositories" ]; then
  echo "❌ No repositories found with Dependabot configuration in '$org'"
  exit 0
fi

echo "$repositories"
echo ""
count=$(echo "$repositories" | wc -l | tr -d ' ')
echo "Total: $count repositories with Dependabot configuration" 
