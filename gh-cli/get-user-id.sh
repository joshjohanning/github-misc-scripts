#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <user>"
  echo "Example: ./get-enterprise-id.sh joshjohanning"
  exit 1
fi

user="$1"

# -H X-Github-Next-Global-ID:1 returns new GraphQL ID
gh api graphql -H X-Github-Next-Global-ID:1 -f user="$user" -f query='
query ($user: String!)
  { user(login: $user) {
    login
    name
    id
  }
}
'
