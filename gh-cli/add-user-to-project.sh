#!/bin/bash

# ---
# title: add-user-to-project.sh
# description: Adds a user to a ProjectV2
# notes: needs: gh auth login -s project
# ---

function print_usage {
  echo "Usage: $0 <organization> <repository> <project-number> <user> <role>"
  echo "Example: ./add-user-to-project.sh joshjohanning-org my-repo 1234 joshjohanning ADMIN"
  echo "Valid roles: ADMIN, WRITER, READER, NONE"
  exit 1
}

if [ -z "$4" ]; then
  print_usage
fi

organization="$1"
repository="$2"
project_number="$3"
user="$4"
role=$(echo "$5" | tr '[:lower:]' '[:upper:]')

case "$role" in
  "ADMIN" | "WRITER" | "READER" | "NONE")
    ;;
  *)
    print_usage
    ;;
esac

# get project id
project_id=$(gh api graphql --paginate -f organization="$organization" -f repository="$repository" -f query='
  query ($organization: String!, $repository: String!) {
    organization (login: $organization) {
      repository (name: $repository) {
        name
        projectsV2 (first: 100) {
          nodes {
            title
            id
            url
            number
          }
        }
      }
    }
  }
' --jq ".data.organization.repository.projectsV2.nodes[] | select(.number == $project_number) | .id")

echo "project_id: $project_id"

# get user id
user_id=$(gh api graphql -H X-Github-Next-Global-ID:1 -f user="$user" -f query='
query ($user: String!)
  { user(login: $user) {
    login
    name
    id
  }
}
' --jq '.data.user.id')

echo "user_id: $user_id"

# get epoch time
epoch=$(date +%s)
# create request.json
cat << EOF > request-$epoch.json
{
  "query": "mutation(\$projectId: ID!, \$collaborators: [ProjectV2Collaborator!]!) { updateProjectV2Collaborators(input: {projectId: \$projectId, collaborators: \$collaborators}) { clientMutationId, collaborators (first:100) { nodes { ... on User { login } } } } }",
  "variables": {
    "projectId": "$project_id",
    "collaborators": [
      {
        "userId": "$user_id",
        "role": "$role"
      }
    ]
  }
}
EOF

token=$(gh auth token)

# couldn't get this to work with gh api, had an error trying to pass in the object, so using curl
curl -H "Authorization: bearer $token" -H "X-Github-Next-Global-ID:1" -H "Content-Type: application/json" -X POST -d @request-$epoch.json https://api.github.com/graphql

rm request-$epoch.json
