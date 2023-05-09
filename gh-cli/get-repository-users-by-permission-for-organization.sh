#!/bin/bash

# this works for users added directly to repo and team
# by default, this is not cumulative; so if you query for push, you get just PUSH
#   - pass in true if you want cumulative permissions (ie: querying for PUSH would return ADMIN and MAINTAIN as well)

if [ $# -lt "2" ]; then
    echo "Usage: $0 <org/repo> <admin|maintain|push|triage|read> <cumulative-true-or-false>"
    echo "Example: ./get-repo-permissions.sh joshjohanning-org/ghas-demo admin false"
    echo "Optionally pipe the output to a file: ./get-repo-permissions.sh joshjohanning-org/ghas-demo admin false > output.csv"
    exit 1
fi

ORG=$1
PERMISSION=$2
CUMULATIVE=$3

# pass in true if you want cumulative permissions (ie: querying for PUSH would return ADMIN and MAINTAIN as well)
if [ -z "$CUMULATIVE" ]; then
    CUMULATIVE="false"
fi

echo "repo,login,permission"

repos=$(gh api graphql --paginate -F owner="${ORG}" -f query='
query ($owner: String!, $endCursor: String) {
  organization(login: $owner) {
    repositories(first: 100, after: $endCursor) {
      nodes {
        name
        licenseInfo {
          name
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '.data.organization.repositories.nodes | .[].name')

while read -r repo; do
  members=$(gh api --paginate "/repos/$ORG/$repo/collaborators?permission=$PERMISSION" --jq '[ .[] | { repo: "'"$repo"'", login: .login, permission: .role_name } ] | sort_by(.permission,.login) | .[] | "\(.repo),\(.login),\(.permission)"')

  if [ "$CUMULATIVE" = "true" ]; then
      # add $repo to each line
      echo "$members"
  else
      echo "$members" | cut -d',' -f1- | grep ",${PERMISSION}$"
  fi

done <<< "$repos"
