#!/bin/bash

# gets a list of self-hosted runners configured at the organization level for all organizations in an enterprise

# for repo-level self-hosted runners, see: `get-self-hosted-runners-in-all-repositories.sh`
# for all self-hosted runners in an org (at org-level and repo-level), see: `get-self-hosted-runners-all-in-organization.sh`

# gh cli's token needs to be able to read at the organization level - run this first if it can't
# gh auth refresh -h github.com -s admin:org -s read:enterprise

# org owner access (or a custom role with ability to manage self-hosted runners at the org level) is required

if [ -z "$1" ]; then
  echo "Usage: $0 <enterprise> <hostname>"
  echo "Example: ./get-organizations-self-hosted-runners-organization-runners.sh avocado-corp github.com > output.tsv"
  exit 1
fi

enterprise="$1"
hostname=${2:-"github.com"}

# Define color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

# we can't do everything in a single call b/c we need to paginate orgs and then paginate repos in the next query (can't do double pagination with gh api)
organizations=$(gh api graphql --hostname $hostname --paginate -f enterpriseName="$enterprise" -f query='
query getEnterpriseOrganizations($enterpriseName: String! $endCursor: String) {
  enterprise(slug: $enterpriseName) {
    organizations(first: 100, after: $endCursor) {
      nodes {
        id
        login
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '.data.enterprise.organizations.nodes[].login')

printf "org\tname\tos\tlabels\tstatus\n"

errors=""

for org in $organizations
do
  output=$(gh api --hostname $hostname --paginate /orgs/$org/actions/runners --jq ".runners[] | [\"$org\", .name, .os, (.labels | map(.name) | join(\",\")), .status] | @tsv" 2>&1)

  if [ $? -ne 0 ]; then
    errors="$errors\nError accessing organization: $org:\n$output"
  elif [ -n "$output" ]; then
    echo "$output"
  fi
done

if [ -n "$errors" ]; then
  echo -e "${RED}\nErrors encountered:\n$errors${NC}"
fi
