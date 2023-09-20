#!/bin/bash

# Adds a user to an organization in an enterprise

# Notes:
#  - for EMU, this currently only works for adding:
#       1. Enterprise owners
#       2. Members who are already added to at least (1) org in the enterprise
#  - gh cli's token needs to be able to admin enterprise: gh auth refresh -h github.com -s admin:enterprise

# role
# - MEMBER: The user is a member of the organization.
# - ADMIN: The user is an administrator/owner of the organization.

function print_usage {
  echo "Usage: $0 <enterprise> <org> <user> <role>"
  echo "Example: ./get-enterprise-id.sh avocado-corp joshjohanning-org joshjohanning admin"
  echo "Valid roles: MEMBER, ADMIN"
  exit 1
}

if [ -z "$4" ]; then
  print_usage
fi

enterprise="$1"
org="$2"
user="$3"
role=$(echo "$4" | tr '[:lower:]' '[:upper:]')

case "$role" in
  "MEMBER" | "ADMIN")
    ;;
  *)
    print_usage
    ;;
esac

enterprise_id=$(gh api graphql -H X-Github-Next-Global-ID:1 -f enterprise="$enterprise" -f query='
query ($enterprise: String!)
  { enterprise(slug: $enterprise) {
    id
  } 
}
' --jq '.data.enterprise.id')

org_id=$(gh api graphql -H X-Github-Next-Global-ID:1 -f organization="$org" -f query='
query ($organization: String!)
  { organization(login: $organization) {
    login
    name
    id 
  }
}
' --jq '.data.organization.id')

user_id=$(gh api graphql -H X-Github-Next-Global-ID:1 -f user="$user" -f query='
query ($user: String!)
  { user(login: $user) {
    login
    name
    id
  }
}
' --jq '.data.user.id')

gh api graphql -H X-Github-Next-Global-ID:1 -f enterpriseId="$enterprise_id" -f organizationId="$org_id" -f userIds="$user_id" -f role=$role -f query='
mutation($enterpriseId: ID!, $organizationId: ID!, $userIds: [ID!]!, $role: OrganizationMemberRole) {
  addEnterpriseOrganizationMember(input: {enterpriseId: $enterpriseId, organizationId: $organizationId, userIds: $userIds, role: $role}) {
    clientMutationId
    users {
      login
      name
      id
    }
  }
}'
