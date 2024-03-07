#!/bin/bash

# creates a (mostly) empty migration for a given organization repository so that it can create a lock

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <repo>"
  echo "Example: ./lock-repository-with-migration.sh joshjohanning-org test-repo-export"
  exit 1
fi

org="$1"
repo="$2"

gh api -X POST /orgs/$org/migrations -f "repositories[]=$org/$repo" -F lock_repositories=true -f "exclude[]=repositories" --jq '{id: .id, state: .state, updated_at: .updated_at}'
