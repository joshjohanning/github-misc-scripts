#!/bin/bash

# returns the most recent migration ID for a given organization repository
# pass in true as the third argument to return only the migration id

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <repo> <return-id-only: true|false>"
  echo "Example: ./get-most-recent-migration-id-for-repository.sh joshjohanning-org test-repo-export"
  exit 1
fi

org="$1"
repo="$2"
return_only_id=${3:-false}

# Make the API call with error handling
migrations=$(gh api -X GET /orgs/$org/migrations -F per_page=100 --jq '.[] | {id: .id, repositories: .repositories.[].full_name, state: .state, created_at: .created_at}' 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  if echo "$migrations" | grep -q "Authorization failed\|HTTP 403"; then
    echo "Error: Authorization failed (HTTP 403)" >&2
    echo "" >&2
    echo "This endpoint requires a Personal Access Token (PAT) instead of OAuth CLI token." >&2
    echo "Please export your PAT as GH_TOKEN:" >&2
    echo "  export GH_TOKEN=your_personal_access_token" >&2
    echo "" >&2
    echo "For more information, visit:" >&2
    echo "https://docs.github.com/migrations/using-ghe-migrator/exporting-migration-data-from-githubcom" >&2
    exit 1
  elif echo "$migrations" | grep -q "Not Found\|HTTP 404"; then
    echo "Error: Organization not found or no access to migrations (HTTP 404)" >&2
    echo "" >&2
    echo "This could mean:" >&2
    echo "- The organization '$org' doesn't exist" >&2
    echo "- You don't have access to view migrations for this organization" >&2
    echo "" >&2
    echo "Note: This endpoint requires a Personal Access Token (PAT)." >&2
    echo "Make sure you have exported your PAT as GH_TOKEN:" >&2
    echo "  export GH_TOKEN=your_personal_access_token" >&2
    exit 1
  else
    echo "Error: Failed to retrieve migrations" >&2
    echo "$migrations" >&2
    exit 1
  fi
fi

if [ "$return_only_id" = "false" ]; then
  most_recent_migration=$(echo "$migrations" | jq -s -r --arg repo "$org/$repo" 'map(select(.repositories == $repo)) | sort_by(.created_at) | last')
else
  most_recent_migration=$(echo "$migrations" | jq -s -r --arg repo "$org/$repo" 'map(select(.repositories == $repo)) | sort_by(.created_at) | last | .id')
fi

# Check if we found a migration for this repository
if [ "$most_recent_migration" = "null" ] || [ -z "$most_recent_migration" ]; then
  echo "Error: No migrations found for repository $org/$repo" >&2
  echo "" >&2
  echo "This could mean:" >&2
  echo "- No migrations exist for this repository" >&2
  echo "- The repository name is incorrect" >&2
  echo "- You don't have access to migrations for this repository" >&2
  exit 1
fi

echo "$most_recent_migration"
