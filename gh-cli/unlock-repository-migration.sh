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

# Get the migration ID (error handling is done in the called script)
id=$(./get-most-recent-migration-id-for-repository.sh $org $repo true)
exit_code=$?

# Check if the migration ID script failed
if [ $exit_code -ne 0 ]; then
  # Error messages already printed by the called script
  exit $exit_code
fi

# If we reach here, the migration ID was found successfully
echo "Migration ID found: $id"
echo "Delegating to unlock-repository-migration-by-id.sh..."

# Delegate to the other script with proper error handling
./unlock-repository-migration-by-id.sh "$org" "$repo" "$id"
