#!/bin/bash

# gets a list of self-hosted runners configured at the enterprise level for an enterprise

# gh cli's token needs to be able to read at the organization level - run this first if it can't
# gh auth refresh -h github.com -s manage_runners:enterprise

# org owner access (or a custom role with ability to manage self-hosted runners at the org level) is required

if [ -z "$1" ]; then
  echo "Usage: $0 <enterprise> <hostname>"
  echo "Example: ./get-organization-self-hosted-runners-organization-runners.sh joshjohanning-org github.com > output.tsv"
  exit 1
fi

enterprise="$1"
hostname=${2:-"github.com"}

printf "name\tos\tlabels\tstatus\n"

gh api --hostname $hostname --paginate /enterprises/$enterprise/actions/runners --jq '.runners[] | [.name, .os, (.labels | map(.name) | join(",")), .status] | @tsv'
