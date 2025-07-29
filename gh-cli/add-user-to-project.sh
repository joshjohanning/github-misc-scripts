#!/bin/bash

# Adds a user to a ProjectV2

# needs: gh auth login -s project

function print_usage {
  echo "Usage: $0 <organization> <repository> <project-number> <role> <user>"
  echo "Example: ./add-user-to-project.sh joshjohanning-org my-repo 1234 ADMIN joshjohanning"
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
user="$5"

case "$role" in
  "ADMIN" | "WRITER" | "READER" | "NONE")
    ;;
  *)
    print_usage
    ;;
esac

# get project id
project_response=$(gh api graphql --paginate -f organization="$organization" -f repository="$repository" -f query='
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
' 2>&1)

# Check if the response contains scope error
if echo "$project_response" | grep -q "INSUFFICIENT_SCOPES\|read:project"; then
  echo "Error: Insufficient permissions to access projects."
  echo "You may need to authorize to projects; i.e.: gh auth login -s project"
  exit 1
fi

project_id=$(echo "$project_response" | jq -r ".data.organization.repository.projectsV2.nodes[] | select(.number == $project_number) | .id")

if [ -z "$project_id" ] || [ "$project_id" = "null" ]; then
  echo "Error: Could not find project with number $project_number in $organization/$repository"
  exit 1
fi

echo "project_id: $project_id"

# get user id
user_response=$(gh api graphql -H X-Github-Next-Global-ID:1 -f user="$user" -f query='
query ($user: String!)
  { user(login: $user) {
    login
    name
    id
  }
}
' 2>&1)

# Check for user API errors
if echo "$user_response" | grep -q "error\|Error"; then
  echo "Error: Could not find user $user"
  exit 1
fi

user_id=$(echo "$user_response" | jq -r '.data.user.id')

if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
  echo "Error: Could not find user $user"
  exit 1
fi

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
response=$(curl -s -H "Authorization: bearer $token" -H "X-Github-Next-Global-ID:1" -H "Content-Type: application/json" -X POST -d @request-$epoch.json https://api.github.com/graphql)

# Check for errors in the final response
if echo "$response" | grep -q '"status": "400"\|"errors"'; then
  echo "Error updating project collaborators:"
  echo "$response"
  echo ""
  echo "You may need to authorize to projects; i.e.: gh auth login -s project"
  rm request-$epoch.json
  exit 1
fi

echo "Successfully added $user to project with role $role"
echo "$response"

rm request-$epoch.json
