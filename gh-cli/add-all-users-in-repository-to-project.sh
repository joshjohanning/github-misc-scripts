#!/bin/bash

# Adds a all users in a repository to a ProjectV2

# needs: gh auth login -s project
# needs: ./add-user-to-project.sh

function print_usage {
  echo "Usage: $0 <organization> <repository> <project-number> <role>"
  echo "Example: ./add-all-users-in-repository-to-project.sh joshjohanning-org my-repo 1234 WRITER"
  echo "Valid roles: ADMIN, WRITER, READER, NONE"
  exit 1
}

if [ -z "$4" ]; then
  print_usage
fi

organization="$1"
repository="$2"
project_number="$3"
role=$(echo "$4" | tr '[:lower:]' '[:upper:]')

case "$role" in
  "ADMIN" | "WRITER" | "READER" | "NONE")
    ;;
  *)
    print_usage
    ;;
esac

# get list of directly added users in a repository
users=$(gh api graphql --paginate -f owner="$organization" -f repo="$repository" -f query='
query($owner: String!, $repo: String!, $endCursor:String) {
  repository(owner: $owner, name: $repo) {
    collaborators(first: 100, affiliation: DIRECT, after:$endCursor) {
      edges {
        node {
          login
          id
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
' --jq '.data.repository.collaborators.edges[].node')

# for each user, add them to the project
for user in $users; do
  user_login=$(echo $user | jq -r '.login')
  echo "Adding $user_login to project $project_id with role $role"
  ./add-user-to-project.sh $organization $repository $project_number $user_login $role
done
