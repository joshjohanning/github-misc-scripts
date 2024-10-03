#!/bin/bash

# gets a list of self-hosted runners configured at the organization level for an organization

# for repo-level self-hosted runners, see: `get-organization-self-hosted-runners-repository-runners.sh`
# for all self-hosted runners in an org (at org-level and repo-level), see: `get-organization-self-hosted-runners-all-runners.sh`

# gh cli's token needs to be able to read at the organization level - run this first if it can't
# gh auth refresh -h github.com -s admin:org

# org owner access (or a custom role with ability to manage self-hosted runners at the org level) is required

if [ -z "$1" ]; then
  echo "Usage: $0 <org> <hostname>"
  echo "Example: ./get-organization-self-hosted-runners-organization-runners.sh joshjohanning-org github.com > output.tsv"
  exit 1
fi

org="$1"
hostname=${2:-"github.com"}

printf "name\tos\tlabels\tstatus\n"

gh api --hostname $hostname --paginate /orgs/$org/actions/runners --jq '.runners[] | [.name, .os, (.labels | map(.name) | join(",")), .status] | @tsv'
