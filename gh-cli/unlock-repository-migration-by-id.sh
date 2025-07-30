#!/bin/bash

# unlocks / deletes the lock for a migrated repository
# you need to get the migration id first; ./get-most-recent-migration-id-for-repository.sh joshjohanning-org test-repo-export

# Note: Use this other script to automatically look up the migration id for the repository: 
# ./unlock-repository-migration.sh joshjohanning-org test-repo-export

if [ -z "$3" ]; then
  echo "Usage: $0 <org> <repo> <migration-id>"
  echo "Example: ./unlock-repository-migration-by-id.sh joshjohanning-org test-repo-export 4451412"
  exit 1
fi

org="$1"
repo="$2"
id="$3"

echo "Attempting to unlock repository $org/$repo with migration ID: $id"

# Capture the API response and check for errors
response=$(gh api -X DELETE /orgs/$org/migrations/$id/repos/$repo/lock 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  # Check for specific error patterns
  if echo "$response" | grep -q "Authorization failed\|HTTP 403"; then
    echo "Error: Authorization failed (HTTP 403)"
    echo ""
    echo "This endpoint requires a Personal Access Token (PAT) instead of OAuth CLI token."
    echo "Please export your PAT as GH_TOKEN:"
    echo "  export GH_TOKEN=your_personal_access_token"
    echo ""
    echo "For more information, visit:"
    echo "https://docs.github.com/migrations/using-ghe-migrator/exporting-migration-data-from-githubcom"
    exit 1
  elif echo "$response" | grep -q "Not Found\|HTTP 404"; then
    echo "Error: Migration or repository lock not found (HTTP 404)"
    echo ""
    echo "This could mean:"
    echo "- The migration ID ($id) is incorrect"
    echo "- The repository is not locked"
    echo "- You don't have access to this migration"
    echo ""
    echo "Note: This endpoint requires a Personal Access Token (PAT)."
    echo "Make sure you have exported your PAT as GH_TOKEN:"
    echo "  export GH_TOKEN=your_personal_access_token"
    exit 1
  else
    echo "Error: Failed to unlock repository"
    echo "$response"
    exit 1
  fi
fi

echo "Successfully unlocked repository $org/$repo"
