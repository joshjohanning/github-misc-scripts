#!/bin/bash

# Gets all repositories in an organization or user account that were created from a specific
# repository template
#
# Note: Uses the GraphQL API to query all repositories in a single paginated call. Tries the
# organization endpoint first, then falls back to the user endpoint. The templateRepository
# field is only populated if the template repository still exists and is accessible.
#
# Usage:
#   ./get-repositories-created-from-template.sh <org-or-user> <template-repo-full-name> [hostname]
#
# Example:
#   ./get-repositories-created-from-template.sh joshjohanning-org joshjohanning/nodejs-actions-starter-template
#   ./get-repositories-created-from-template.sh joshjohanning joshjohanning/nodejs-actions-starter-template
#   ./get-repositories-created-from-template.sh joshjohanning-org joshjohanning/nodejs-actions-starter-template ghes.example.com

if [ -z "$2" ]; then
  echo "Usage: $0 <org-or-user> <template-repo-full-name> [hostname]"
  echo "Example: $0 joshjohanning-org joshjohanning/nodejs-actions-starter-template"
  exit 1
fi

org="$1"
template_repo="$2"
hostname="${3:-github.com}"

echo "Finding repositories in '$org' created from template '$template_repo'..."
echo ""

# try organization first, fall back to user
results=$(gh api graphql --hostname "$hostname" --paginate -F owner="$org" -f query='
query ($owner: String!, $endCursor: String) {
  organization(login: $owner) {
    repositories(first: 100, after: $endCursor) {
      nodes {
        nameWithOwner
        templateRepository {
          nameWithOwner
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq "[.data.organization.repositories.nodes[] | select(.templateRepository.nameWithOwner == \"$template_repo\") | .nameWithOwner] | .[]" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$results" ]; then
  results=$(gh api graphql --hostname "$hostname" --paginate -F owner="$org" -f query='
query ($owner: String!, $endCursor: String) {
  user(login: $owner) {
    repositories(first: 100, after: $endCursor, ownerAffiliations: OWNER) {
      nodes {
        nameWithOwner
        templateRepository {
          nameWithOwner
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq "[.data.user.repositories.nodes[] | select(.templateRepository.nameWithOwner == \"$template_repo\") | .nameWithOwner] | .[]")
fi

echo "$results"
