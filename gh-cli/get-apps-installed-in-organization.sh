#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  exit 1
fi

org="$1"

gh api "/orgs/$org/installations" --paginate --jq '.installations[].app_slug'
