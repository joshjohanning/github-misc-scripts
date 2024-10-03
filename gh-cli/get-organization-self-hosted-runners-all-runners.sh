#!/bin/bash

# gets a list of all self-hosted runners in an organization, including org-level and repo-level runners

# gh cli's token needs to be able to read at the organization level - run this first if it can't
# gh auth refresh -h github.com -s admin:org

# org owner access (or a custom role with ability to manage self-hosted runners at the org level) is required

if [ -z "$1" ]; then
  echo "Usage: $0 <org> <hostname>"
  echo "Example: ./get-organization-self-hosted-runners-all-runners.sh joshjohanning-org github.com > output.tsv"
  exit 1
fi

org="$1"
hostname=${2:-"github.com"}

printf "type\trepo\tname\tos\tlabels\tstatus\n"

gh api --hostname $hostname --paginate /orgs/$org/actions/runners --jq '.runners[] | ["org", "n/a", .name, .os, (.labels | map(.name) | join(",")), .status] | @tsv'

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

for repo in $repos; do
  gh api --hostname $hostname --paginate /repos/$repo/actions/runners --jq ".runners[] | [\"repo\", \"$repo\", .name, .os, (.labels | map(.name) | join(\",\")), .status] | @tsv"
done
