#!/bin/bash

# gets a list of all self-hosted runners in an organization, including org-level and repo-level runners

# gh cli's token needs to be able to read at the organization level - run this first if it can't
# gh auth refresh -h github.com -s admin:org

# org owner access (or a custom role with ability to manage self-hosted runners at the org level) is required

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  echo "Example: ./get-self-hosted-runners-all-in-organization.sh joshjohanning-org"
  exit 1
fi

org="$1"

printf "type\trepo\tname\tos\tlabels\tstatus\n"

gh api --paginate /orgs/$org/actions/runners --jq '.runners[] | ["org", "n/a", .name, .os, (.labels | map(.name) | join(",")), .status] | @tsv'

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

for repo in $repos; do
  gh api --paginate /repos/$repo/actions/runners --jq ".runners[] | [\"repo\", \"$repo\", .name, .os, (.labels | map(.name) | join(\",\")), .status] | @tsv"
done
