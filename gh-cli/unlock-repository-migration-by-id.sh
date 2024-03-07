#!/bin/bash

# unlocks / deletes the lock for a migrated repository
# you need to get the migration id first; ./get-most-recent-migration-id-for-repository.sh joshjohanning-org test-repo-export

# Note: Use this other script to automatically look up the migration id for the repository: 
# ./unlock-migrated-repository.sh joshjohanning-org test-repo-export

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <migration-id>"
  echo "Example: ./unlock-repository-migration-by-id.sh joshjohanning-org test-repo-export 4451412"
  exit 1
fi

org="$1"
repo="$2"
id="$3"

gh api -X DELETE /orgs/$org/migrations/$id/repos/$repo/lock
