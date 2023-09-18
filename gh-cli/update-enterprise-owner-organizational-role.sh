#!/bin/bash

# Notes:
#  - this script uses the enterprise owner's ability to add themselves to an organization in the enterprise
#  - this script only adds the person running the script to the organization, and that person needs to be an enterprise owner
#  - gh cli's token needs to be able to admin enterprise: gh auth refresh -h github.com -s admin:enterprise

# organizationRole
# - DIRECT_MEMBER: The user is a member of the organization.
# - OWNER: The user is an administrator/owner of the organization.
# - UNAFFILIATED: The user is a not a member of the organization. (leave the organization)

function print_usage {
  echo "Usage: $0 <enterprise> <org> <role>"
  echo "Example: ./get-enterprise-id.sh avocado-corp joshjohanning-org owner"
  echo "Valid roles: DIRECT_MEMBER, OWNER, UNAFFILIATED (leave organization)"
  exit 1
}

if [ -z "$3" ]; then
   print_usage
fi

enterprise="$1"
org="$2"
role=$(echo "$3" | tr '[:lower:]' '[:upper:]')

case "$role" in
  "DIRECT_MEMBER" | "OWNER" | "UNAFFILIATED")
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

gh api graphql -f enterprise_id="$enterprise_id" -f organization_id="$org_id" -f organization_role="$role" -f query='
mutation ($enterprise_id: ID! $organization_id: ID! $organization_role: RoleInOrganization!) { 
  updateEnterpriseOwnerOrganizationRole(input: { enterpriseId: $enterprise_id organizationId: $organization_id organizationRole: $organization_role}) { 
      clientMutationId
      message
   } 
}'
