#!/bin/bash

# gh cli's token needs to be able to admin org - run this if it fails
# gh auth refresh -h github.com -s admin:org

# see also: 
# - https://docs.github.com/en/enterprise-cloud@latest/migrations/using-github-enterprise-importer/migrating-organizations-with-github-enterprise-importer/migrating-organizations-from-githubcom-to-github-enterprise-cloud?tool=api#step-3-check-the-status-of-your-migration

# Usage: 
# ./add-users-to-team-from-list.sh <migration_id>
#

if [ -z "$1" ]; then
  echo "Usage: $0 <migration_id>"
  echo "Example: ./get-gei-migration-status RM_abcdef"
  exit 1
fi

MIGRATION_ID="$1"

gh api graphql -f id=$MIGRATION_ID -f query='
query($id: ID!) {
  node(id: $id) {
    ... on Migration {
        id,
        sourceUrl,
        migrationLogUrl,
        migrationSource {
            name
        },
        state,
        warningsCount,
        failureReason,
        repositoryName
    }
  }
}'
