#!/bin/bash

# downloads the most recent migration archive/export for a given organization repository
# gets the most recent migration id for a given organization repository and then tries to download the archive

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <repo>"
  echo "Example: ./download-migration-archive-for-repository.sh joshjohanning-org test-repo-export"
  exit 1
fi

org="$1"
repo="$2"

id=$(./get-most-recent-migration-id-for-repository.sh $org $repo true)

gh api /orgs/$org/migrations/$id/archive > $repo-archive.tar.gz
