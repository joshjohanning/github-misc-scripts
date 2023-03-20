#!/bin/bash

# Usage: 
# Step 1: ./new-users-to-add-to-project.sh <org> <repo> <file>
# Step 2: Don't delete the `<file>` as it functions as your user database

if [ $# -lt "3" ]; then
    echo "Usage: $0 <org> <repo> <file>"
    echo "Example: $0 joshjohanning-org my-repo users.txt"
    echo "The <file> should be used as the database to catalog which users are new/not"
    exit 1
fi

ORG="$1"
REPO="$2"
FILE="$3"

if [ ! -f "$FILE" ]; then
    touch $FILE
fi

users=$(gh api graphql --paginate -f organizationName="${ORG}" -f repoName="${REPO}" -f query='
query getOutsideCollaborators($organizationName: String! $repoName: String! $endCursor: String) {
  repository(owner: $organizationName, name: $repoName) {
    id
    collaborators(first: 100, affiliation: OUTSIDE, after: $endCursor) {
      edges {
        node {
          login
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}')

# list users on repo
# echo $users | jq -r '.data.repository.collaborators.edges[].node.login' 

echo $users | jq -r '.data.repository.collaborators.edges[].node.login' | while read -r user; do
    if ! grep -q $user $FILE; then
        # user is new, write them to the file and echo them
        echo "${user}"
        echo "${user}" >> $FILE
    fi
done
