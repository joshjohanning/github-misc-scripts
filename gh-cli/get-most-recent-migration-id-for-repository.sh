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

migrations=$(gh api -X GET /orgs/$org/migrations -F per_page=100 --jq '.[] | {id: .id, repositories: .repositories.[].full_name, state: .state, created_at: .created_at}')

if [ "$return_only_id" = "false" ]; then
  most_recent_migration=$(echo "$migrations" | jq -s -r --arg repo "$org/$repo" 'map(select(.repositories == $repo)) | sort_by(.created_at) | last')
else
  most_recent_migration=$(echo "$migrations" | jq -s -r --arg repo "$org/$repo" 'map(select(.repositories == $repo)) | sort_by(.created_at) | last | .id')
fi

echo "$most_recent_migration"
