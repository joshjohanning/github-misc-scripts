#!/bin/bash

# Sets (or adds) a user to an organization with a specified role

# Notes:
#  - caps (per authenticated user running the API):
#     - 50 requests per 24 hours for free plans
#     - 500 requests per 24 hours for organizations on paid plans
#     - these caps do not apply to Enterprise Managed Users (EMU)
#  - gh cli's token needs to be able to admin org: gh auth refresh -h github.com -s admin:org

# role
# - MEMBER: The user is a member of the organization.
# - ADMIN: The user is an administrator/owner of the organization.

function print_usage {
  echo "Usage: $0 <org> <user> <role>"
  echo "Example: ./get-enterprise-id.sh avocado-corp joshjohanning-org joshjohanning admin"
  echo "Valid roles: MEMBER, ADMIN"
  exit 1
}

if [ -z "$3" ]; then
  print_usage
fi

org="$1"
user="$2"
role=$(echo "$3" | tr '[:lower:]' '[:lower:]')

case "$role" in
  "member" | "admin")
    ;;
  *)
    print_usage
    ;;
esac

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /orgs/$org/memberships/$user \
  -f role="$role"
