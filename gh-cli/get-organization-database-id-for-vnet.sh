#!/bin/bash

# This script retrieves the databaseId of your organization to be used in the Vnet injection scripts
# https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#1-obtain-the-databaseid-for-your-organization

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  echo "Example: ./get-enterprise-id.sh joshjohanning-org"
  exit 1
fi

org="$1"

gh api graphql -f organization="$org" -f query='
query ($organization: String!)
  { organization(login: $organization) {
    login
    databaseId 
  }
}
'
