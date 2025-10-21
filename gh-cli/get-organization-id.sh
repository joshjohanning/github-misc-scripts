#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  echo "Example: ./get-organization-id.sh joshjohanning-org"
  exit 1
fi

org="$1"

# -H X-Github-Next-Global-ID:1 returns new GraphQL ID
gh api graphql -H X-Github-Next-Global-ID:1 -f organization="$org" -f query='
query ($organization: String!)
  { organization(login: $organization) {
    login
    name
    id
  }
}
'
