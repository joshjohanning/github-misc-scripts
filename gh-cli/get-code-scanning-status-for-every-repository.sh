#!/bin/bash

# Usage: ./get-code-scanning-status-for-every-repository.sh <org> > csv.csv

if [ -z "$1" ]; then
    echo "Usage: $0 <org>"
    exit 1
fi

org=$1

repos=$(gh api graphql --paginate -F org="$org" -f query='query($org: String!$endCursor: String){
organization(login:$org) {
    repositories(first:100,after: $endCursor) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        owner {
          login
        }
        name
      }
    }
  }
}' --template '{{range .data.organization.repositories.nodes}}{{printf "%s/%s\n" .owner.login .name}}{{end}}')

for repo in $repos
do
  result=$(gh api /repos/$repo/code-scanning/analyses?per_page=1 2>/dev/null)
  # if result not empty
  if echo "$result" | grep -q "no analysis found"; then
    echo "$repo, no code scanning results"
  else
    echo "$result" | jq -r --arg repo_name "$repo" '.[] | [$repo_name, .tool.name, .ref, .created_at, .analysis_key] | @csv' 2>/dev/null
  fi
done
