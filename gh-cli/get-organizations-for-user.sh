#!/bin/bash

# gets the list of organizations a user is a member of

# this only returns organizations accessible to the person running the script 
# - i.e.: organizations they are also a member of, or public organizations

if [ -z "$1" ]; then
  echo "Usage: $0 <user>"
  echo "Example: ./get-organizations-for-user joshjohanning"
  exit 1
fi

user="$1"

gh api graphql -f user="$user" -f query='
query ($user: String!)
  { user(login: $user) {
    organizations(first: 100) {
      nodes {
        login
        name
        id
      }
      pageInfo{
        hasNextPage
        endCursor
      }
    }
  }
}
'
