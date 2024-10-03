#!/bin/bash

# gets a list of all repo-level self-hosted runners in all repos in an organization

# for org-level self-hosted runners, see: `get-organization-self-hosted-runners-organization-runners.sh`
# for all self-hosted runners in an org (at org-level and repo-level), see: `get-organization-self-hosted-runners-all-runners.sh`
  
if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  echo "Example: ./get-organization-self-hosted-runners-repository-runners.sh joshjohanning-org github.com > output.tsv"
  exit 1
fi

org="$1"
hostname=${2:-"github.com"}

repos=$(gh api graphql --hostname $hostname --paginate -F org="$org" -f query='query($org: String!$endCursor: String){
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

printf "repo\tname\tos\tlabels\tstatus\n"

for repo in $repos; do
  gh api --hostname $hostname --paginate /repos/$repo/actions/runners --jq ".runners[] | [\"$repo\", .name, .os, (.labels | map(.name) | join(\",\")), .status] | @tsv"
done
