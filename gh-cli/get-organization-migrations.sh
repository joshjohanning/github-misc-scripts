#!/bin/bash

# this returns the migrations (exports) against an organization

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  echo "Example: ./get-organization-migrations.sh joshjohanning-org"
  exit 1
fi

org="$1"

gh api -X GET /orgs/$org/migrations -F per_page=100 --jq '.[] | {id: .id, repositories: .repositories.[].full_name, state: .state, created_at: .created_at}'
