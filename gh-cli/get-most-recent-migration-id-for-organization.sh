#!/bin/bash

# returns the most recent migration ID for a given organization

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  echo "Example: ./get-most-recent-migration-id-for-organization.sh joshjohanning-org"
  exit 1
fi

org="$1"

gh api /orgs/joshjohanning-org/migrations --jq 'sort_by(.created_at) | last | .id'
