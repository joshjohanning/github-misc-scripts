#!/bin/bash

# gets a list of self-hosted runners configured at the organization level for an organization

# for repo-level self-hosted runners, see: `get-self-hosted-runners-in-all-repositories.sh`
# for all self-hosted runners in an org (at org-level and repo-level), see: `get-self-hosted-runners-all-in-organization.sh`

# gh cli's token needs to be able to read at the organization level - run this first if it can't
# gh auth refresh -h github.com -s admin:org

# org owner access (or a custom role with ability to manage self-hosted runners at the org level) is required

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  echo "Example: ./get-self-hosted-runners-organization-runners.sh joshjohanning-org"
  exit 1
fi

org="$1"

printf "name\tos\tlabels\tstatus\n"

gh api --paginate /orgs/$org/actions/runners --jq '.runners[] | [.name, .os, (.labels | map(.name) | join(",")), .status] | @tsv'
