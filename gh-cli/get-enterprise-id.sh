#!/bin/bash

# gh cli's token needs to be able to read enterprise - run this first if it can't
# gh auth refresh -h github.com -s read:enterprise

if [ -z "$1" ]; then
  echo "Usage: $0 <enterprise>"
  echo "Example: ./get-enterprise-id.sh avocado-corp"
  exit 1
fi

enterprise="$1"

# -H X-Github-Next-Global-ID:1 returns new GraphQL ID
gh api graphql -H X-Github-Next-Global-ID:1 -f enterprise="$enterprise" -f query='
query ($enterprise: String!)
  { enterprise(slug: $enterprise) {
    slug
    name
    id
    databaseId
  }
}
'
