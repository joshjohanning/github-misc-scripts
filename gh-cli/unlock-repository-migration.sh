#!/bin/bash

# unlocks / deletes the lock for a migrated repository
# gets the most recent migration id for a given organization repository and then tries to delete the lock

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <repo>"
  echo "Example: ./unlock-repository-migration.sh joshjohanning-org test-repo-export"
  exit 1
fi

org="$1"
repo="$2"

id=$(./get-most-recent-migration-id-for-repository.sh $org $repo true)

gh api -X DELETE /orgs/$org/migrations/$id/repos/test-repo-export/lock
